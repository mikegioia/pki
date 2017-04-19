#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# Sets up a new server certificate, signed by the TLS
# certificate authority.
##

## Get working directory
rootpath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
basepath="$rootpath/.."

## Source the config
. $basepath/config

## Source the colors
. $basepath/etc/bash/colors

## Export the ENV variables
export TLSCANAME=$tlsCA
export BASEPATH=$basepath
export CABASEURL=$caBaseURL
export COUNTRYNAME=$countryName
export ORGNAME=$organizationName
export TLSCOMMONNAME=$tlsCommonName
export ORGUNITNAME=$organizationalUnitName

## Script vars
fqdns=()

## Help message
function showHelp {
    echo -e "${yellow}Usage:${NC}"
    echo "  $0 [options] [command]"
    echo ""
    echo -e "${yellow}Options:${NC}"
    echo -e "  ${green}--help      -h${NC} Display this help message."
    echo ""
    echo -e "${yellow}Available Commands:${NC}"
    echo -e "  ${green}create        ${NC} Creates a new server TLS cert."
    echo -e "  ${green}bundle        ${NC} Creates cert bundle for existing TLS cert."
    echo -e "  ${green}revoke        ${NC} Revokes a certificate."
    echo ""
    echo -e "Default command is ${green}create${NC} if none is specified."
}

## Info message
function showCreateMessage {
    echo -e "${yellow}You will be prompted to enter as many domain names as you wish.${NC}"
    echo -e "${yellow}It's often best to include both example.org and www.example.org${NC}"
    echo -e "${yellow}as the FQDNs for a server certificate. The common name should be${NC}"
    echo -e -n "${yellowBold}www.example.org${NC}"
    echo -e "${yellow} in this case.${NC}"
    echo "";
}

## Begin prompting the user for domains to add to the
## server alternate name (SAN).
function getFqdn {
    echo -n -e "${green}Enter fully qualified domain name:${NC} "
    read fqdn
    echo ""
    fqdns=("${fqdns[@]}" $fqdn)
    askAgain
}

function askAgain {
    echo -n "Do you want to add another domain? [y/N] "
    read answer
    echo ""
    if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
        getFqdn
    fi
}

## Check if domains were added, if not exit
function checkFqdns {
    if ! [[ -n "${fqdns[@]}" ]] ; then
        echo -e "${redBold}You didn't enter any domains!${NC}"
        exit 1
    fi
}

## Confirm the list of domains
function joinFqdns {
    separator="$1"
    regex="$( printf "${separator}%s" "${fqdns[@]}" )"
    regex="${regex:${#separator}}" # remove leading separator
    echo "${regex}"
}

function confirmFqdns {
    list=$(joinFqdns ', ')
    echo -n "The following domains will be used: "
    echo -e "${yellowBold}${list}${NC}"
    echo -n "Is this correct? [y/N] "
    read answer
    echo ""

    if ! [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
        echo -e "${redBold}Aborted!${NC}"
        exit 0
    fi
}

## Prompt user for a certificate and key name
function getCertName {
    echo -n -e "${green}Enter certificate name (ex. example.org):${NC} "
    read certName
    echo ""

    if ! [[ -n "$certName" ]] ; then
        echo -e "${redBold}You didn't enter a certificate name!${NC}"
        echo ""
        getCertName
    fi
}

## Join FQDNs into the SAN and export
function exportSan {
    san=$(joinFqdns ',DNS:')
    san="DNS:${san}"
    export SAN=$san
}

## Create the TLS certs directory
function createCertDirs {
    mkdir -p $basepath/certs/tls-ca/private
    chmod 700 $basepath/certs/tls-ca/private
    echo "*.key" > $basepath/certs/tls-ca/private/.gitignore
    echo -n "*.p12" >> $basepath/certs/tls-ca/private/.gitignore
}

## Generate the CSR
function genCsr {
    if ! [[ -f "$basepath/certs/tls-ca/private/$certName.key" ]] ; then
        openssl req -new \
            -sha256 \
            -config $basepath/etc/server.conf \
            -out $basepath/certs/tls-ca/$certName.csr \
            -keyout $basepath/certs/tls-ca/private/$certName.key
    else
        openssl req -new \
            -sha256 \
            -config $basepath/etc/server.conf \
            -out $basepath/certs/tls-ca/$certName.csr \
            -key $basepath/certs/tls-ca/private/$certName.key
    fi
}

function doGenCsr {
    if [[ -f "$basepath/certs/tls-ca/$certName.csr" ]] ; then
        echo -e "${red}${certName} CSR exists!${NC}"
        echo -n "Do you want to create a new one? [y/N] "
        read answer
        echo ""
        if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
            genCsr
        fi
    else
        genCsr
    fi
}

## Create the server certificate
function genCrt {
    openssl ca \
        -config $basepath/etc/tls-ca.conf \
        -in $basepath/certs/tls-ca/$certName.csr \
        -out $basepath/certs/tls-ca/$certName.crt \
        -extensions server_ext
}

function doGenCert {
    if [[ -f "$basepath/certs/tls-ca/$certName.crt" ]] ; then
        echo -e "${red}${certName} certificate exists!${NC}"
        echo -n "Do you want to create a new one? [y/N] "
        read answer
        echo ""
        if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
            genCrt
        fi
    else
        genCrt
    fi
}

## Generate the server certificate bundle
function genBundle {
    if ! [[ -f "$basepath/certs/tls-ca/$certName.crt" ]] ; then
        echo -e "${redBold}You haven't created a certificate for this FQDN!${NC}"
        exit 1
    fi
    if ! [[ -f "$basepath/ca/$tlsChainCA.pem" ]] ; then
        echo -e "${redBold}No TLS CA certificate chain!${NC}"
        echo ""
    else
        cat $basepath/certs/tls-ca/$certName.crt $basepath/ca/$tlsChainCA.pem > \
            $basepath/certs/tls-ca/$certName.bundle.pem
    fi
}

function doGenBundle {
    echo -n "Do you want to generate a server certificate chain? [y/N] "
    read answer
    echo ""
    if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
        genBundle
    fi
}

function finish {
    echo -e "${greenBold}Done!${NC}"
}

## If no arguments came in, default to create
if [[ -z "$@" ]] ; then
    set "create"
fi

## Loop through command parameters
for i
do
case $i in
    -\? | -h | help )
        showHelp
        exit 0
        ;;
    create )
        ## Create a new certificate
        showCreateMessage
        getFqdn
        checkFqdns
        confirmFqdns
        getCertName
        exportSan
        createCertDirs
        doGenCsr
        doGenCert
        doGenBundle
        finish
        exit 0
        ;;
    bundle )
        ## Create a new certificate bundle
        getCertName
        createCertDirs
        doGenBundle
        finish
        exit 0
        ;;
    revoke ) 
        ## Revoke a certificate
        # @TODO
        # Get serial
        # issue revoke
        finish
        exit 0
        ;;
    * )
        echo -e "${redBold}Unknown arg '$i'${NC}";
        exit 1
        ;;
esac
done