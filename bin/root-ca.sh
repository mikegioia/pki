#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# Sets up the Primary Root CA
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
export COUNTRYNAME=$countryName
export ORGNAME=$organizationName
export ROOTCOMMONNAME=$rootCommonName
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
    echo -e "  ${green}create        ${NC} Creates a new Root CA."
    echo ""
    echo -e "Default command is ${green}create${NC} if none is specified."
}

## Info message
function showCreateMessage {
    echo -e "${yellow}You will be creating a new Root Certificate Authority.${NC}"
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
    mkdir -p $basepath/ca/root-ca/private $basepath/ca/root-ca/db $basepath/crl $basepath/certs
    chmod 700 $basepath/ca/root-ca/private
    echo -n "*.key" > $basepath/ca/root-ca/private/.gitignore
}

## Create database
function createDatabase {
    if ! [[ -f "$basepath/ca/root-ca/db/$rootCA.db" ]] ; then
        cp /dev/null $basepath/ca/root-ca/db/$rootCA.db
    fi
    if ! [[ -f "$basepath/ca/root-ca/db/$rootCA.db.attr" ]] ; then
        cp /dev/null $basepath/ca/root-ca/db/$rootCA.db.attr
    fi
    if ! [[ -f "$basepath/ca/root-ca/db/$rootCA.crt.srl" ]] ; then
        echo 01 > $basepath/ca/root-ca/db/$rootCA.crt.srl
    fi
    if ! [[ -f "$basepath/ca/root-ca/db/$rootCA.crl.srl" ]] ; then
        echo 01 > $basepath/ca/root-ca/db/$rootCA.crl.srl
    fi
}

## Create CA request
## Use -key ca/root-ca/private/root-ca.key to generate
## a new CSR.
function genCsr {
    keyPath="$basepath/ca/root-ca/private/$rootCA.key"

    if ! [[ -f $keyPath && -s $keyPath ]] ; then
        echo -e "${yellow}A new key will now be created.${NC}"
        echo -e "${yellowBold}You must enter a password between 4 and 1024 characters.${NC}"

        openssl req -new \
            -sha256 \
            -config $basepath/etc/root-ca.conf \
            -out $basepath/ca/$rootCA.csr \
            -keyout $basepath/ca/root-ca/private/$rootCA.key
    else
        openssl req -new \
            -sha256 \
            -config $basepath/etc/root-ca.conf \
            -out $basepath/ca/$rootCA.csr \
            -key $basepath/ca/root-ca/private/$rootCA.key
    fi
}

## Check if the CSR exists. If so, ask the user if they
## want to replace it. Otherwise, just create the CSR.
function checkCsr {
    if [[ -f "$basepath/ca/$rootCA.csr" ]] ; then
        echo -e "${red}Root CA CSR exists!${NC}"
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
    openssl ca -selfsign \
        -config $basepath/etc/root-ca.conf \
        -in $basepath/ca/$rootCA.csr \
        -out $basepath/ca/$rootCA.crt \
        -extensions root_ca_ext
}

## Check if certificate exists and prompt to overwrite
function checkCrt {
    if [[ -f "$basepath/ca/$rootCA.crt" ]] ; then
        echo -e "${red}Root CA certificate exists!${NC}"
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
        -config $basepath/etc/root-ca.conf \
        -out $basepath/crl/$rootCA.crl
}

## Ask to create a CRL file
function checkCrl {
    echo -n "Do you want to generate a CRL? (y/N): "
    read answer
    echo ""

    if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
        genCrl
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
        finish
        ;;
    * )
        echo -e "${redBold}Unknown arg '$i'${NC}";
        exit 1
        ;;
esac
done