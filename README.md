# pqchat-c - Pure-PQC TLS Echo (OpenSSL 3.5 / MLKEM768 + ML-DSA-65)

[![CI](https://github.com/shutendohg/pqchat-c/actions/workflows/ci.yml/badge.svg)](https://github.com/shutendohg/pqchat-c/actions/workflows/ci.yml)

**pqchat-c** is a small C project that establishes a **pure post-quantum** (non-hybrid) TLS 1.3 session using OpenSSL 3.5 and performs a simple echo.

- **KEM:** `MLKEM768` (IANA: ML-KEM-768)  
- **Signatures:** `ML-DSA-65` for CA and server certs  
- **TLS:** 1.3 only  
- **Network:** IPv6/IPv4 via an IPv6 socket with `IPV6_V6ONLY=0`  
- **CI:** GitHub Actions (build + smoke test)

## Quick Start

``` bash
# If OpenSSL 3.5 is at $HOME/opt/openssl-3.5:
./scripts/run_demo.sh

# If it lives elsewhere:
OPENSSL_PREFIX=/path/to/openssl-3.5 ./scripts/run_demo.sh
```

## What this project demonstrates
- **Pure-PQC TLS 1.3:** forces KEM = `MLKEM768` (non-hybrid)
- **PQC certificates:** CA and server certs are signed with `ML-DSA-65`
- **Verification:** the client verifies hostname = `localhost`
- **Separation of concerns:** thin TLS abstraction in `tls_backend.h` with an OpenSSL 3.5 backend
- **Small footprint:** a few hundred lines + CI

## Requirements
- Linux (x86_64)
- OpenSSL **3.5.0** available somewhere on your system
- Build toolchain (`build-essential` or equivalent)

**Path requirement?** No hard requirement. The default path used by the demo is `$HOME/opt/openssl-3.5`, but you can override it:

``` bash
OPENSSL_PREFIX=/your/openssl-3.5 ./scripts/run_demo.sh
```

## How to run the demo
``` bash
# Default prefix
./scripts/run_demo.sh

# Custom prefix
OPENSSL_PREFIX=/your/openssl-3.5 ./scripts/run_demo.sh
```
