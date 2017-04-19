#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# Sets up the Software CA
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
export SOFTWARECANAME=$softwareCA
export ROOTCOMMONNAME=$rootCommonName
export ORGUNITNAME=$organizationalUnitName
export SOFTWARECOMMONNAME=$softwareCommonName


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
    echo -e "${yellow}You will be creating a new Software Certificate Authority.${NC}"
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
    mkdir -p $basepath/ca/software-ca/private $basepath/ca/software-ca/db
    chmod 700 $basepath/ca/software-ca/private
    echo -n "*.key" > $basepath/ca/software-ca/private/.gitignore
}

## Create database
function createDatabase {
    if ! [[ -f "$basepath/ca/software-ca/db/$softwareCA.db" ]] ; then
        cp /dev/null $basepath/ca/software-ca/db/$softwareCA.db
    fi
    if ! [[ -f "$basepath/ca/software-ca/db/$softwareCA.db.attr" ]] ; then
        cp /dev/null $basepath/ca/software-ca/db/$softwareCA.db.attr
    fi
    if ! [[ -f "$basepath/ca/software-ca/db/$softwareCA.crt.srl" ]] ; then
        echo 01 > $basepath/ca/software-ca/db/$softwareCA.crt.srl
    fi
    if ! [[ -f "$basepath/ca/software-ca/db/$softwareCA.crl.srl" ]] ; then
        echo 01 > $basepath/ca/software-ca/db/$softwareCA.crl.srl
    fi
}

## Create CA request
## Use -key ca/software-ca/private/software-ca.key to generate
## a new CSR.
function genCsr {
    keyPath="$basepath/ca/software-ca/private/$softwareCA.key"

    if ! [[ -f $keyPath && -s $keyPath ]] ; then
        openssl req -new \
            -sha256 \
            -config $basepath/etc/software-ca.conf \
            -out $basepath/ca/$softwareCA.csr \
            -keyout $basepath/ca/software-ca/private/$softwareCA.key
    else
        openssl req -new \
            -sha256 \
            -config $basepath/etc/software-ca.conf \
            -out $basepath/ca/$softwareCA.csr \
            -key $basepath/ca/software-ca/private/$softwareCA.key
    fi
}

## Check if the CSR exists. If so, ask the user if they
## want to replace it. Otherwise, just create the CSR.
function checkCsr {
    if [[ -f "$basepath/ca/$softwareCA.csr" ]] ; then
        echo -e "${red}Software CA CSR exists!${NC}"
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
        -in $basepath/ca/$softwareCA.csr \
        -out $basepath/ca/$softwareCA.crt \
        -extensions signing_ca_ext
}

## Check before creating certificate
function checkCrt {
    if [[ -f "$basepath/ca/$softwareCA.crt" ]] ; then
        echo -e "${red}Software CA certificate exists!${NC}"
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
        -config $basepath/etc/software-ca.conf \
        -out $basepath/crl/$softwareCA.crl
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
    if [[ -f "$basepath/ca/$softwareCA.crt" && -f "$basepath/ca/$rootCA.crt" ]] ; then
        cat $basepath/ca/$softwareCA.crt $basepath/ca/$rootCA.crt > \
            $basepath/ca/$softwareChainCA.pem
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