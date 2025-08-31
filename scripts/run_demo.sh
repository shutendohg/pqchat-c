#!/usr/bin/env bash
# run_demo.sh - local smoke demo for pqchat-c
# Supports BACKEND=openssl (default) or BACKEND=wolfssl
# This script:
#   1) prints OpenSSL 3.5 info (used for s_client and cert gen)
#   2) builds the project with selected BACKEND
#   3) generates demo certs if missing (ML-DSA-65)
#   4) starts server, verifies handshake via OpenSSL s_client (MLKEM768)
#   5) runs custom client for one echo round trip

set -euo pipefail

# ---- config (can be overridden by env) ---------------------------------------
BACKEND="${BACKEND:-openssl}" # openssl | wolfssl
OPENSSL_PREFIX="${OPENSSL_PREFIX:-$HOME/opt/openssl-3.5}"
WOLFSSL_PREFIX="${WOLFSSL_PREFIX:-/usr/local}"

# pick lib64 if exists
libdir() {
    local p="$1"
    if [ -d "$p/lib64" ]; then echo "$p/lib64"; else echo "$p/lib"; fi
}
OSSL_LIBDIR="$(libdir "$OPENSSL_PREFIX")"
WOLF_LIBDIR="$(libdir "$WOLFSSL_PREFIX")"

echo "[demo] BACKEND=${BACKEND}"
echo "[demo] OPENSSL_PREFIX=${OPENSSL_PREFIX}"
echo "[demo] WOLFSSL_PREFIX=${WOLFSSL_PREFIX}"

# ---- step 0: OpenSSL 3.5 presence (for s_client & certs) ---------------------
OPENSSL="${OPENSSL_PREFIX}/bin/openssl"
if [ ! -x "${OPENSSL}" ]; then
    echo "[demo] ERROR: ${OPENSSL} not found. Build or set OPENSSL_PREFIX." >&2
    exit 1
fi

echo "[demo] OpenSSL version:"
env LD_LIBRARY_PATH="${OSSL_LIBDIR}" \
    OPENSSL_MODULES="${OSSL_LIBDIR}/ossl-modules" \
    "${OPENSSL}" version -a

echo -n "[demo] TLS groups: "
env LD_LIBRARY_PATH="${OSSL_LIBDIR}" \
    OPENSSL_MODULES="${OSSL_LIBDIR}/ossl-modules" \
    "${OPENSSL}" list -tls-groups | tr '\n' ' ' | sed 's/  */ /g'
echo

# ---- step 1: build project ---------------------------------------------------
echo "[demo] building project (BACKEND=${BACKEND})..."
make -s clean
make -s BACKEND="${BACKEND}" OPENSSL_PREFIX="${OPENSSL_PREFIX}" WOLFSSL_PREFIX="${WOLFSSL_PREFIX}"

echo "[demo] ldd (server/client)"
ldd ./server | egrep 'ssl|crypto|wolfssl' || true
ldd ./client | egrep 'ssl|crypto|wolfssl' || true

# ---- step 2: generate certs if missing --------------------------------------
if [ ! -f cert/srv.crt ]; then
    echo "[demo] generating demo certificates..."
    OPENSSL_CONF="$(pwd)/openssl.cnf"
    if [ ! -f "${OPENSSL_CONF}" ]; then
        echo "[demo] ERROR: openssl.cnf not found. Run repo root." >&2
        exit 1
    fi
    OPENSSL="${OPENSSL}" OPENSSL_CONF="${OPENSSL_CONF}" ./scripts/gen_certs.sh
else
    echo "[demo] certs exist; skipping generation"
fi

# ---- step 3: start server with proper runtime env ----------------------------
# For openssl backend: need OpenSSL's provider path
# For wolfssl backend: need wolfSSL's lib at runtime (also OpenSSL lib for s_client next)
echo "[demo] starting server..."
if [ "${BACKEND}" = "openssl" ]; then
    export LD_LIBRARY_PATH="${OSSL_LIBDIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    export OPENSSL_MODULES="${OSSL_LIBDIR}/ossl-modules"
else
    export LD_LIBRARY_PATH="${WOLF_LIBDIR}:${OSSL_LIBDIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    unset OPENSSL_MODULES || true
fi

./server &
PID=$!
trap 'kill ${PID} 2>/dev/null || true' EXIT
sleep 1

# ---- step 4: verify handshake using OpenSSL s_client (pure MLKEM768) ---------
echo "[demo] checking with openssl s_client..."
env LD_LIBRARY_PATH="${OSSL_LIBDIR}" \
    OPENSSL_MODULES="${OSSL_LIBDIR}/ossl-modules" \
    "${OPENSSL}" s_client -connect [::1]:4433 -tls1_3 -groups MLKEM768 -CAfile cert/ca.crt </dev/null |
    tee /tmp/s_client.txt

grep -q "Negotiated TLS1.3 group: MLKEM768" /tmp/s_client.txt || {
    echo "[demo] ERROR: MLKEM768 was not negotiated." >&2
    exit 1
}

# ---- step 5: one echo round trip --------------------------------------------
echo "[demo] running self client..."
printf "hello\n" | ./client | tee /tmp/out.txt
grep -Eq "^echo: ?hello$" /tmp/out.txt
echo "[demo] OK ✅  (pure PQC: KEM=MLKEM768, sig=ML-DSA-65)"
