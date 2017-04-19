#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# Sets up the TLS CA
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
export ROOTCANAME=$rootCA
export CABASEURL=$caBaseURL
export COUNTRYNAME=$countryName
export ORGNAME=$organizationName
export TLSCOMMONNAME=$tlsCommonName
export ROOTCOMMONNAME=$rootCommonName
export ORGUNITNAME=$organizationalUnitName

## Info message
function showCreateMessage {
    echo -e "${yellow}You will be creating a new TLS/SSL Certificate Authority.${NC}"
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
    mkdir -p $basepath/ca/tls-ca/private $basepath/ca/tls-ca/db
    chmod 700 $basepath/ca/tls-ca/private
    echo -n "*.key" > $basepath/ca/tls-ca/private/.gitignore
}

## Create database
function createDatabase {
    if ! [[ -f "$basepath/ca/tls-ca/db/$tlsCA.db" ]] ; then
        cp /dev/null $basepath/ca/tls-ca/db/$tlsCA.db
    fi
    if ! [[ -f "$basepath/ca/tls-ca/db/$tlsCA.db.attr" ]] ; then
        cp /dev/null $basepath/ca/tls-ca/db/$tlsCA.db.attr
    fi
    if ! [[ -f "$basepath/ca/tls-ca/db/$tlsCA.crt.srl" ]] ; then
        echo 01 > $basepath/ca/tls-ca/db/$tlsCA.crt.srl
    fi
    if ! [[ -f "$basepath/ca/tls-ca/db/$tlsCA.crl.srl" ]] ; then
        echo 01 > $basepath/ca/tls-ca/db/$tlsCA.crl.srl
    fi
}

## Create CA request
## Use -key ca/tls-ca/private/tls-ca.key to generate
## a new CSR.
function genCsr {
    keyPath="$basepath/ca/tls-ca/private/$tlsCA.key"

    if ! [[ -f $keyPath && -s $keyPath ]] ; then
        openssl req -new \
            -sha256 \
            -config $basepath/etc/tls-ca.conf \
            -out $basepath/ca/$tlsCA.csr \
            -keyout $basepath/ca/tls-ca/private/$tlsCA.key
    else
        openssl req -new \
            -sha256 \
            -config $basepath/etc/tls-ca.conf \
            -out $basepath/ca/$tlsCA.csr \
            -key $basepath/ca/tls-ca/private/$tlsCA.key
    fi
}

## Check before creating CSR
function checkCsr {
    ## Check if the CSR exists. If so, ask the user if they
    ## want to replace it. Otherwise, just create the CSR.
    if [[ -f "$basepath/ca/$tlsCA.csr" ]] ; then
        echo -e "${red}TLS CA CSR exists!${NC}"
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
        -in $basepath/ca/$tlsCA.csr \
        -out $basepath/ca/$tlsCA.crt \
        -extensions signing_ca_ext
}

## Check before creating certificate
function checkCrt {
    if [[ -f "$basepath/ca/$tlsCA.crt" ]] ; then
        echo -e "${red}TLS CA certificate exists!${NC}"
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
        -config $basepath/etc/tls-ca.conf \
        -out $basepath/crl/$tlsCA.crl
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
    if [[ -f "$basepath/ca/$tlsCA.crt" && -f "$basepath/ca/$rootCA.crt" ]] ; then
    cat $basepath/ca/$tlsCA.crt $basepath/ca/$rootCA.crt > \
        $basepath/ca/$tlsChainCA.pem
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