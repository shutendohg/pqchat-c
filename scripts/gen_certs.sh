#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Use OpenSSL3.5(if needed, set PATH)
: "${OPENSSL:=openssl}"

CONF="${PWD}/openssl.cnf"
mkdir -p cert

# CA（ML-DSA-65）
"$OPENSSL" req -x509 -new -newkey mldsa65 \
	-keyout cert/ca.key -out cert/ca.crt -nodes \
	-subj "/CN=PQ CA" -days 365 \
	-extensions v3_ca -config "$CONF"

# server key/CSR（ML-DSA-65）
"$OPENSSL" req -new -newkey mldsa65 -nodes \
	-keyout cert/srv.key -out cert/srv.csr \
	-subj "/CN=localhost" -config "$CONF"

# Use a signature and completion（SAN=localhost）
"$OPENSSL" x509 -req -in cert/srv.csr -out cert/srv.crt \
	-CA cert/ca.crt -CAkey cert/ca.key -CAcreateserial -days 365 \
	-extfile "$CONF" -extensions v3_server

echo "OK: cert/srv.crt completed its genearation"
