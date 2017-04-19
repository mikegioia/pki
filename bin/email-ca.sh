#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# Sets up the Email CA
##

## Get working directory
rootpath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
basepath="$rootpath/.."

## Source the config
. $basepath/config

## Source the colors
. $basepath/etc/bash/colors

## Export the ENV variables
export BASEPATH=$basepath
export ROOTCANAME=$rootCA
export CABASEURL=$caBaseURL
export EMAILCANAME=$emailCA
export COUNTRYNAME=$countryName
export ORGNAME=$organizationName
export ROOTCOMMONNAME=$rootCommonName
export EMAILCOMMONNAME=$emailCommonName
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
    echo -e "  ${green}create        ${NC} Creates a new Email CA."
    echo ""
    echo -e "Default command is ${green}create${NC} if none is specified."
}

## Info message
function showCreateMessage {
    echo -e "${yellow}You will be creating a new Email Certificate Authority.${NC}"
    echo -e "${yellow}This will create new directories, certificates, keys and ${NC}"
    echo -e "${yellow}other files, and may overwrite files with the same names ${NC}"
    echo -e "${yellow}that already exist.${NC}"
    echo -n "Do you want to proceed? [y/N] "
    read answer
    echo ""
    if [[ "$answer" != "y" && "$answer" != "Y" ]] ; then
        exit 0
    fi
}

## Create directories
function createDirectories {
    mkdir -p $basepath/ca/email-ca/private $basepath/ca/email-ca/db
    chmod 700 $basepath/ca/email-ca/private
    echo -n "*.key" > $basepath/ca/email-ca/private/.gitignore
}

## Create database
function createDatabase {
    if ! [[ -f "$basepath/ca/email-ca/db/$emailCA.db" ]] ; then
        cp /dev/null $basepath/ca/email-ca/db/$emailCA.db
    fi
    if ! [[ -f "$basepath/ca/email-ca/db/$emailCA.db.attr" ]] ; then
        cp /dev/null $basepath/ca/email-ca/db/$emailCA.db.attr
    fi
    if ! [[ -f "$basepath/ca/email-ca/db/$emailCA.crt.srl" ]] ; then
        echo 01 > $basepath/ca/email-ca/db/$emailCA.crt.srl
    fi
    if ! [[ -f "$basepath/ca/email-ca/db/$emailCA.crl.srl" ]] ; then
        echo 01 > $basepath/ca/email-ca/db/$emailCA.crl.srl
    fi
}

## Create CA request
## Use -key ca/email-ca/private/email-ca.key to generate
## a new CSR.
function genCsr {
    if ! [[ -f "$basepath/ca/email-ca/private/$emailCA.key" ]] ; then
        openssl req -new \
            -sha256 \
            -config $basepath/etc/email-ca.conf \
            -out $basepath/ca/$emailCA.csr \
            -keyout $basepath/ca/email-ca/private/$emailCA.key
    else
        openssl req -new \
            -sha256 \
            -config $basepath/etc/email-ca.conf \
            -out $basepath/ca/$emailCA.csr \
            -key $basepath/ca/email-ca/private/$emailCA.key
    fi
}

## Check before creating CSR
function checkCsr {
    ## Check if the CSR exists. If so, ask the user if they
    ## want to replace it. Otherwise, just create the CSR.
    if [[ -f "$basepath/ca/$emailCA.csr" ]] ; then
        echo -e "${red}Email CA CSR exists!${NC}"
        echo -n "Do you want to create a new one? (y/N): "
        read answer
        echo ""
        if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
            genCsr
        fi
    else
        genCsr
    fi
}

## Create CA certificate
function genCrt {
    openssl ca \
        -config $basepath/etc/root-ca.conf \
        -in $basepath/ca/$emailCA.csr \
        -out $basepath/ca/$emailCA.crt \
        -extensions signing_ca_ext
}

## Check before creating certificate
function checkCrt {
    if [[ -f "$basepath/ca/$emailCA.crt" ]] ; then
        echo -e "${red}Email CA certificate exists!${NC}"
        echo -n "Do you want to create a new one? (y/N): "
        read answer
        echo ""
        if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
            genCrt
        fi
    else
        genCrt
    fi
}

## Create CRL
function genCrl {
    openssl ca -gencrl \
        -config $basepath/etc/email-ca.conf \
        -out $basepath/crl/$emailCA.crl
}

## Check before creating CRL
function checkCrl {
    echo -n "Do you want to generate a CRL? (y/N): "
    read answer
    echo ""

    if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
        genCrl
    fi
}

## Create PEM bundle
function createBundle {
    if [[ -f "$basepath/ca/$emailCA.crt" && -f "$basepath/ca/$rootCA.crt" ]] ; then
        cat $basepath/ca/$emailCA.crt $basepath/ca/$rootCA.crt > \
            $basepath/ca/$emailChainCA.pem
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
        ## Create a new CA
        showCreateMessage
        createDirectories
        createDatabase
        checkCsr
        checkCrt
        checkCrl
        createBundle
        finish
        ;;
    * )
        echo -e "${redBold}Unknown arg '$i'${NC}";
        exit 1
        ;;
esac
done