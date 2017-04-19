#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# Sets up a new TLS client certificate, signed by the TLS
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

## Help message
function showHelp {
    echo -e "${yellow}Usage:${NC}"
    echo "  $0 [options] [command]"
    echo ""
    echo -e "${yellow}Options:${NC}"
    echo -e "  ${green}--help      -h${NC} Display this help message."
    echo ""
    echo -e "${yellow}Available Commands:${NC}"
    echo -e "  ${green}create        ${NC} Creates a new client TLS cert."
    echo -e "  ${green}bundle        ${NC} Creates PKCS#12 bundle for existing client cert."
    echo -e "  ${green}revoke        ${NC} Revokes a client certificate."
    echo ""
    echo -e "Default command is ${green}create${NC} if none is specified."
}

## Info message
function showCreateMessage {
    echo -e "${yellow}You will be prompted to enter certificate name. This needs to.${NC}"
    echo -e "${yellow}be unique and should follow a naming format.${NC}"
    echo "";
}

## Prompt user for a certificate and key name
function getCertName {
    echo -n -e "${green}Enter certificate name (ex. stallman_richard):${NC} "
    read certName
    echo ""

    if ! [[ -n "$certName" ]] ; then
        echo -e "${redBold}You didn't enter a certificate name!${NC}"
        echo ""
        getCertName
    fi
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
            -config $basepath/etc/client.conf \
            -out $basepath/certs/tls-ca/$certName.csr \
            -keyout $basepath/certs/tls-ca/private/$certName.key
    else
        openssl req -new \
            -sha256 \
            -config $basepath/etc/client.conf \
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

## Create the client certificate
function genCrt {
    openssl ca \
        -config $basepath/etc/tls-ca.conf \
        -in $basepath/certs/tls-ca/$certName.csr \
        -out $basepath/certs/tls-ca/$certName.crt \
        -policy extern_pol \
        -extensions client_ext
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

## Generate the client certificate bundle
function genBundle {
    if ! [[ -f "$basepath/certs/tls-ca/$certName.crt" ]] ; then
        echo -e "${redBold}You haven't created a certificate for this FQDN!${NC}"
        exit 1
    fi
    if ! [[ -f "$basepath/ca/$tlsChainCA.pem" ]] ; then
        echo -e "${redBold}No TLS CA certificate chain!${NC}"
        echo ""
    else
        ## Get the user's name for the bundle
        echo -n "Enter the user's name (i.e. Richard Stallman): "
        read userName
        echo ""
        openssl pkcs12 -export \
            -name "$userName" \
            -caname "$tlsCommonName" \
            -caname "$rootCommonName" \
            -inkey $basepath/certs/tls-ca/private/$certName.key \
            -in $basepath/certs/tls-ca/$certName.crt \
            -certfile $basepath/ca/$tlsChainCA.pem \
            -out $basepath/certs/tls-ca/private/$certName.p12
    fi
}

function doGenBundle {
    echo -n "Do you want to generate a client certificate bundle? [y/N] "
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
        getCertName
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