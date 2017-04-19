#!/bin/bash
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
export ORGUNITNAME=$organizationalUnitName
export ROOTCOMMONNAME=$rootCommonName

## Create directories
mkdir -p $basepath/ca/root-ca/private $basepath/ca/root-ca/db $basepath/crl $basepath/certs
chmod 700 $basepath/ca/root-ca/private
echo -n "*.key" > $basepath/ca/root-ca/private/.gitignore

## Create database
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

## Create CA request
## Use -key ca/root-ca/private/root-ca.key to generate
## a new CSR.
function genCsr {
    if ! [[ -f "$basepath/ca/root-ca/private/$rootCA.key" ]] ; then
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

## Create CA certificate
function genCrt {
    openssl ca -selfsign \
        -config $basepath/etc/root-ca.conf \
        -in $basepath/ca/$rootCA.csr \
        -out $basepath/ca/$rootCA.crt \
        -extensions root_ca_ext \
        -enddate 20501231235959Z
}

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

## Create CRL
echo -n "Do you want to generate a CRL? (y/N): "
read answer
echo ""

if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
    openssl ca -gencrl \
        -config $basepath/etc/root-ca.conf \
        -out $basepath/crl/$rootCA.crl
fi

echo -e "${greenBold}Done!${NC}"