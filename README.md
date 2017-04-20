# Certificate Authority Management Utilities

This repo contains helpful and easy to use utilities for managing the public key
infrastructure at your organization, or for yourself. You can generate a Root
Certificate Authority, intermediate CAs like a Software Signing or Email CA,
individual web server certificates for your domains to use both locally and on
the Internet, and personal email and browser PKCS-12 certificates for email and
web-based authentication.

This project heavily utilizes OpenSSL and requires Bash.

---

## 0. Contents

1. [Introduction](#1-introduction)
2. [Creating a Root Certificate Authority](#2-creating-a-root-certificate-authority)
    1. [Update Config File](#21-update-config-file)
    2. [Run Utility](#22-run-utility)
3. [Creating Intermediate Certificate Authorities](#3-creating-intermediate-certificate-authorities)
    1. [Run Utilities](#31-run-utilities)
4. [Creating a Web SSL Certificate for a Domain](#4-creating-a-web-ssl-certificate-for-a-domain)
    1. [Run Utility](#41-run-utility)
5. [Creating a Client SSL Certificate](#5-creating-a-client-ssl-certificate)
    1. [Run Utility](#51-run-utility)
    2. [Browser Bundle](#52-browser-bundle)
6. [Final Notes](#6-final-notes)
    1. [Security](#61-security)
    2. [Web Server Install](#62-web-server-install)
    3. [Browser Install](#63-browser-install)

---

## 1. Introduction

All of the utilities are in the `bin` directory. These files use the config
files in the `etc` directory. There's no reason to ever edit any thing in these
two folders.

When you run the tools, they will create the folders `ca`, `certs`, and `crl`.
These will contain your generated certificates, private keys, certificate
signing requests, certificate revocation lists, database, and serial files that
OpenSSL generates.

## 2. Creating a Root Certificate Authority

The first thing you'll want to do is create the Root CA. This is the master
certificate and key that will sign all of the Intermediate CAs. Intermediate
CAs are the TLS CA for signing both web server and web client certificates, the
Software CA for signing software packages, and the Email CA for signing S/MIME
certificates.

Structuring your PKI hierarchy this way allows the Root key to stay private or
behind multiple layers of security. The Intermediate keys, if ever exposed,
could be revoked without putting the entire system in jeopardy. This is a best
practice that we'll adhere to in these utilities.

### 2.1 Update Config File

Update the `config` file in this directory to have the correct names and info.
These names will be embedded into the certificates.

### 2.2 Run Utility

To generate the Root CA:

```
$> ./bin/root-ca.sh
```

This will guide you through the set-up process. It will create the following
files and folders:

 - `/ca` Certificate Authority files
     - `/root-ca` Root CA files, certificates and signing requests
         - `/db` Root CA database and serial files
         - `/private` Key files, this is untracked in git
            - `RootCA.key` Private key file for Root CA
         - `RootCA.crt` Certificate file
         - `RootCA.csr` Signing request file
- `/crl` Ceritificate revocation lists
    - `RootCA.crl` Public revocation list file, this should ultimately go on
      your webserver. The URL will be embedded into certificates.

## 3. Creating Intermediate Certificate Authorities

Now that we have the Root CA, we'll create all of the Intermediate CAs. The only
required one to finish this guide is the TLS CA but it's simple to generate them
all.

3.1 Run Utilities

To generate the TLS CA:

```
$> ./bin/tls-ca.sh
```

This will guide you through the set-up process. It will create the following
files and folders:

 - `/ca`
     - `/tls-ca` TLS CA files, certificates and signing requests
         - `/db` TLS CA database and serial files
         - `/private` Key files, this is untracked in git
            - `TLSCA.key` Private key file for Root CA
         - `TLSCA.crt` Certificate file
         - `TLSCA.csr` Signing request file
         - `TLSCAChain.pem` Chained certificate file containing the Root and TLS CA
           certificates.
- `/crl`
    - `TLSCA.crl` Public revocation list file, this should ultimately go on your
      webserver. The URL will be embedded into certificates.

Similar files are created for the other two Intermediate CAs. To generate the
Software CA:

```
$> ./bin/software-ca.sh
```

To generate the Email CA:

```
$> ./bin/email-ca.sh
```

## 4. Creating a Web SSL Certificate for a Domain

The TLS CA is used to sign web server certificates, which is the most common
application and use-case for PKI and probably why you're here :P

Creating a new server certificate is simple, and you can just follow the
on-screen instructions. Just make sure to read the few instructions included.
Just remember two things:

1. The fully qualified domain name (FQDN) is usually of the form www.domain.com.
2. When adding FQDNs at the beginning, add both the www and non-www domains. For
   example, both www.example.org and example.org. The script will prompt you to
   add as many as you'd like. You can probably even do a wildcard but I haven't
   tested that yet.
3. When adding the `Organiztion Name` during the CSR questions, make sure it's
   the same company name you have in your `config` file. Otherwise, the process
   will halt and you will have to start over.

### 4.1 Run Utility

To generate a new web server certificate:

```
$> ./bin/server.sh
```

This will create the following files and folders:

 - `/certs` Server and client files
     - `/tls-ca` TLS CA signed files
         - `/private` Key files, this is untracked in git
            - `example.org.key` Private key file for your web domain. Your web
              server will need this file.
         - `example.org.crt` Web domain certificate file
         - `example.org.csr` Signing request file
         - `example.org.bundle.pem` Certificate bundle containing the server's
           signed and issued certificate, the Intermediate TLS CA's certificate,
           and the Root CA's certificate. Your web server will need this file.

## 5. Creating a Client SSL Certificate

An often unused, but very powerful security mechanism is PKCS-12 client
certificates. These are certificates issued to people or devices that are
signed by the Intermediate CA and grant that person or device access to the
web server. In nginx, this is done through the use of `ssl_client_certificate`
and pointing it to the `TLSCAChain.pem` file copied to your web server.

This utility will generate a password protected `.p12` file that the user can
import into their web browser. You can then set up your webserver to optionally
require a client certificate to gain access. This client certificate replaces
the need for the user to keep a password and provides greater security to an
application.

### 5.1 Run Utility

To generate a client certificate:

```
$> ./bin/client.sh
```

Here are some helpful notes:

1. This will prompt you to create a password for the client's private key. Make
   sure you enter one at least 4 characters long or the script will halt.
2. During the CSR process, it will ask your for the "Organization Name". Make
   sure this is the same as the "Company Name" in the `config` file.
3. During the CSR process, enter the user's name into the "Common Name" field,
   and enter their email address into the "Email Address".
4. You will need the TLS CA private key password to sign this client
   certificate.

The following files are generated:

 - `/certs`
     - `/tls-ca`
         - `/private`
            - `stallman_richard.key` Private key file for the client.
            - `stallman_richard.p12` P12 browser bundle file. This needs to be
              imported into the browser along with the trusted Root CA
              certificate file.
         - `stallman_richard.crt` Client certificate file
         - `stallman_richard.csr` Signing request file

### 5.2 Browser Bundle

At the end of the script, you are asked if you want to generate "client
certificate bundle". This is the `.p12` file from earlier. If you do this, you
will be prompted for a name to embed into the file. This name will display to
the user when they are asked by their browser to select a certificate.

You do not need to enter an export password but it is strongly recommended that
you do. The `.p12` files should be treated like private keys since they contain
both the public and private parts.

## 6. Final Notes

### 6.1 Security

Always make sure `.key` and `.p12` files remain untracked. This is automatically
done for you through `.gitignore` files but it's important that you know this.
These files should also be `chmod 400` to protect them on the web servers.

### 6.2 Web Server Install

Your web server will want the `example.org.key` and `example.org.bundle.pem`
files for it to load the SSL correctly. If you're using client certificates,
also copy over the `TLSCAChain.pem` file.

### 6.3 Browser Install

Once you create a server certificate, your browser will not immediate trust it.
To do this automatically for all server certificates that you create, add your
Root CA certificate file to your browsers list of trusted authorities. This is
the file `RootCA.crt` (or similarly named) in the `ca` folder.

If you're on MacOS, double click this file and make sure you open it again in
KeyChain, expand the Trust tab, and make sure everything is always trusted.

For Chrome, go to Settings -> Show Advanced Settings -> Manage Certificates.
This will prompt KeyChain in MacOS or show you a window with an Authorites tab.
If you see the Chrome Certificates window, then go to the Authorities tab and
click "Import" and select the Root CA certificate file. Make sure you trust this
authority.

For Firefox, go to Preferences -> Advanced -> Certificates and click "View
Certificates". Click the Authorities tab and then click "Import" and select the
Root CA certificate file. Make sure you trust this authority.

You may need to restart your browser for this to take effect, since SSL is often
cached.