#!/usr/bin/env bash
# Generate demo certificates:
# - CA (ML-DSA-65) is created once then reused
# - Server key/cert (ML-DSA-65) is generated each run
# - Uses openssl.cnf for SAN=localhost and extensions

set -euo pipefail
cd "$(dirname "$0")/.."

OPENSSL="${OPENSSL:-openssl}" # Allow OPENSSL=/path/to/openssl override
CONF="${PWD}/openssl.cnf"

mkdir -p cert

echo "[gen] using OPENSSL=$OPENSSL"
$OPENSSL version -a || true

if [[ ! -f "$CONF" ]]; then
	echo "[gen][ERR] openssl.cnf not found: $CONF"
	exit 1
fi

# CA (ML-DSA-65) - reuse if exists
if [[ -f cert/ca.crt ]]; then
	echo "[gen] reuse CA: cert/ca.crt"
else
	echo "[gen] generating CA (ML-DSA-65)"
	$OPENSSL req -x509 -new -newkey mldsa65 \
		-keyout cert/ca.key -out cert/ca.crt -nodes \
		-subj "/CN=PQ CA" -days 365 \
		-extensions v3_ca -config "$CONF"
fi

# Server (ML-DSA-65, SAN=localhost)
echo "[gen] generating server key/csr (ML-DSA-65)"
$OPENSSL req -new -newkey mldsa65 -nodes \
	-keyout cert/srv.key -out cert/srv.csr \
	-subj "/CN=localhost" -config "$CONF"

echo "[gen] signing server cert with CA"
$OPENSSL x509 -req -in cert/srv.csr -out cert/srv.crt \
	-CA cert/ca.crt -CAkey cert/ca.key -CAcreateserial -days 365 \
	-extfile "$CONF" -extensions v3_server

echo "[gen] done: cert/srv.crt"
