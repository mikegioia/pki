#!/bin/bash
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
export BASEPATH=$basepath
export TLSCANAME=$tlsCA
export CABASEURL=$caBaseURL
export COUNTRYNAME=$countryName
export ORGNAME=$organizationName
export ORGUNITNAME=$organizationalUnitName
export TLSCOMMONNAME=$tlsCommonName

## Create directories
mkdir -p $basepath/ca/tls-ca/private $basepath/ca/tls-ca/db
chmod 700 $basepath/ca/tls-ca/private
echo -n "*.key" > $basepath/ca/tls-ca/private/.gitignore

## Create database
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

## Create CA request
## Use -key ca/tls-ca/private/tls-ca.key to generate
## a new CSR.
function genCsr {
    if ! [[ -f "$basepath/ca/tls-ca/private/$tlsCA.key" ]] ; then
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

## Check if the CSR exists. If so, ask the user if they
## want to replace it. Otherwise, just create the CSR.
if [[ -f "$basepath/ca/$tlsCA.csr" ]] ; then
    echo -e "${red}TLS CA CSR exists!{$NC}"
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
        -in $basepath/ca/$tlsCA.csr \
        -out $basepath/ca/$tlsCA.crt \
        -extensions signing_ca_ext
}

if [[ -f "$basepath/ca/$tlsCA.crt" ]] ; then
    echo -e "${red}TLS CA certificate exists!{$NC}"
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
        -config $basepath/etc/tls-ca.conf \
        -out $basepath/crl/$tlsCA.crl
fi

## Create PEM bundle
if [[ -f "$basepath/ca/$tlsCA.crt" && -f "$basepath/ca/$rootCA.crt" ]] ; then
cat $basepath/ca/$tlsCA.crt $basepath/ca/$rootCA.crt > \
    $basepath/ca/$tlsChainCA.pem
fi

echo -e "${greenBold}Done!${NC}"