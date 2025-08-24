#!/usr/bin/env bash
# Demo runner:
# - Detect OpenSSL 3.5 prefix (lib/lib64)
# - Build project (link against 3.5 and embed RPATH via Makefile)
# - Generate PQC certs if missing (ML-DSA-65)
# - Verify pure-PQC negotiation with s_client (MLKEM768)
# - Echo roundtrip using our client

set -euo pipefail
cd "$(dirname "$0")/.."

# Detect OpenSSL 3.5 location (override by OPENSSL_PREFIX=/path/to/ossl-3.5)
PREFIX="${OPENSSL_PREFIX:-$HOME/opt/openssl-3.5}"
OPENSSL="${OPENSSL:-$PREFIX/bin/openssl}"

# Pick lib or lib64
LIBDIR="$PREFIX/lib"
[[ -f "$LIBDIR/libcrypto.so.3" ]] || LIBDIR="$PREFIX/lib64"
if [[ ! -f "$LIBDIR/libcrypto.so.3" ]]; then
    echo "[demo][ERR] libcrypto.so.3 not found under $PREFIX"
    echo "           Set OPENSSL_PREFIX to the correct OpenSSL 3.5 prefix."
    exit 1
fi

# Make runtime pick our libs/providers (even if RPATH exists, this is safer)
export LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}"
export OPENSSL_MODULES="$LIBDIR/ossl-modules"
export PKG_CONFIG_PATH="$LIBDIR/pkgconfig"
export PATH="$PREFIX/bin:$PATH"

echo "[demo] OPENSSL=$OPENSSL"
$OPENSSL version -a || true
echo "[demo] TLS groups: $($OPENSSL list -tls-groups | tr '\n' ' ' | sed 's/  */ /g')" || true

# Ensure MLKEM768 exists in this openssl build
if ! $OPENSSL list -tls-groups | grep -q 'MLKEM768'; then
    echo "[demo][ERR] This openssl does not support MLKEM768."
    exit 1
fi

echo "[demo] building project..."
make -s clean
make -s OPENSSL_PREFIX="$PREFIX"

echo "[demo] ldd (server/client)"
ldd ./server | egrep 'ssl|crypto' || true
ldd ./client | egrep 'ssl|crypto' || true

# Generate certs if missing (server cert)
if [[ ! -f cert/srv.crt ]]; then
    echo "[demo] generating certificates..."
    OPENSSL="$OPENSSL" ./scripts/gen_certs.sh
fi

# Start server and verify PQC-only negotiation
./server &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
sleep 1

echo "[demo] checking with openssl s_client..."
$OPENSSL s_client -connect [::1]:4433 -tls1_3 -groups MLKEM768 \
    -CAfile cert/ca.crt </dev/null 2>&1 | tee /tmp/sclient.txt || true

if ! grep -q "Negotiated TLS1.3 group: MLKEM768" /tmp/sclient.txt; then
    echo "[demo][ERR] Could not confirm MLKEM768 negotiation via s_client."
    exit 1
fi

echo "[demo] running self client..."
printf "hello\n" | ./client | tee /tmp/out.txt
grep -Eq 'echo:[[:space:]]*hello' /tmp/out.txt

echo "[demo] OK ✅  (pure PQC: KEM=MLKEM768, sig=ML-DSA-65)"
