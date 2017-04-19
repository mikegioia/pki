#!/bin/bash
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
export EMAILCANAME=$emailCA
export CABASEURL=$caBaseURL
export COUNTRYNAME=$countryName
export ORGNAME=$organizationName
export ORGUNITNAME=$organizationalUnitName
export EMAILCOMMONNAME=$emailCommonName

## Create directories
mkdir -p $basepath/ca/email-ca/private $basepath/ca/email-ca/db
chmod 700 $basepath/ca/email-ca/private
echo -n "*.key" > $basepath/ca/email-ca/private/.gitignore

## Create database
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

## Create CA certificate
function genCrt {
    openssl ca \
        -config $basepath/etc/root-ca.conf \
        -in $basepath/ca/$emailCA.csr \
        -out $basepath/ca/$emailCA.crt \
        -extensions signing_ca_ext
}

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

## Create CRL
echo -n "Do you want to generate a CRL? (y/N): "
read answer
echo ""

if [[ "$answer" == "y" || "$answer" == "Y" ]] ; then
    openssl ca -gencrl \
        -config $basepath/etc/email-ca.conf \
        -out $basepath/crl/$emailCA.crl
fi

## Create PEM bundle
if [[ -f "$basepath/ca/$emailCA.crt" && -f "$basepath/ca/$rootCA.crt" ]] ; then
    cat $basepath/ca/$emailCA.crt $basepath/ca/$rootCA.crt > \
        $basepath/ca/$emailChainCA.pem
fi

echo -e "${greenBold}Done!${NC}"