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

## Create directories
mkdir -p $basepath/ca/software-ca/private $basepath/ca/software-ca/db
chmod 700 $basepath/ca/software-ca/private
echo -n "*.key" > $basepath/ca/software-ca/private/.gitignore

## Create database
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

## Create CA request
## Use -key ca/software-ca/private/software-ca.key to generate
## a new CSR.
function genCsr {
    if ! [[ -f "$basepath/ca/software-ca/private/$softwareCA.key" ]] ; then
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

## Create CA certificate
function genCrt {
    openssl ca \
        -config $basepath/etc/root-ca.conf \
        -in $basepath/ca/$softwareCA.csr \
        -out $basepath/ca/$softwareCA.crt \
        -extensions signing_ca_ext
}

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

## Create CRL
echo -n "Do you want to generate a CRL? (y/N): "
read answer
echo ""

if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
    openssl ca -gencrl \
        -config $basepath/etc/software-ca.conf \
        -out $basepath/crl/$softwareCA.crl
fi

## Create PEM bundle
if [[ -f "$basepath/ca/$softwareCA.crt" && -f "$basepath/ca/$rootCA.crt" ]] ; then
    cat $basepath/ca/$softwareCA.crt $basepath/ca/$rootCA.crt > \
        $basepath/ca/$softwareChainCA.pem
fi

echo -e "${greenBold}Done!${NC}"