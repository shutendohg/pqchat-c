// wolfSSL backend for pqchat-c (pure ML-KEM-768 + ML-DSA)
// Build-time requirement: wolfSSL built with --enable-kyber --enable-dilithium

#include "tls_backend.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// wolfSSL headers (options.h first is recommended by wolfSSL)
#include <wolfssl/options.h>
#include <wolfssl/ssl.h>

struct tls_ctx {
	WOLFSSL_CTX *ctx;
};

struct tls {
	WOLFSSL *ssl;
	int fd;
};

// Choose pure ML-KEM-768 only (no hybrid)
static int set_pqc_group_on_ctx(WOLFSSL_CTX *ctx) {
	// Prefer numeric constant API to avoid string-name differences.
	const int grp = WOLFSSL_ML_KEM_768; // pure ML-KEM-768
	// Use group-preference at the context level if available:
	// wolfSSL_CTX_set_groups(ctx, &grp, 1) exists on recent wolfSSL,
	// fall back to _set1_groups_list with a string if needed.
#ifdef HAVE_WOLFSSL_CTX_SET_GROUPS
	if (wolfSSL_CTX_set_groups(ctx, &grp, 1) != WOLFSSL_SUCCESS) {
		fprintf(stderr, "[wolfssl] wolfSSL_CTX_set_groups failed\n");
		return 0;
	}
#else
	if (wolfSSL_CTX_set1_groups_list(ctx, "MLKEM768") != WOLFSSL_SUCCESS) {
		fprintf(stderr, "[wolfssl] set1_groups_list(MLKEM768) failed\n");
		return 0;
	}
#endif
	return 1;
}

// Set TLS 1.3 only and PQC group on a fresh context
static WOLFSSL_CTX *mk_ctx_common(int is_server) {
	static int inited = 0;
	if (!inited) {
		wolfSSL_Init();
		inited = 1;
	}

	const WOLFSSL_METHOD *meth =
		is_server ? wolfTLSv1_3_server_method() : wolfTLSv1_3_client_method();
	if (!meth)
		return NULL;

	WOLFSSL_CTX *c = wolfSSL_CTX_new(meth);
	if (!c)
		return NULL;

	// Enforce TLS 1.3 (method already selects 1.3, but be explicit for safety)
#ifdef WOLFSSL_TLS13
	wolfSSL_CTX_SetMinVersion(c, WOLFSSL_TLSV1_3);
	wolfSSL_CTX_SetMaxVersion(c, WOLFSSL_TLSV1_3);
#endif

	fprintf(stderr, "[dbg] about to set groups: MLKEM768\n");
	if (!set_pqc_group_on_ctx(c)) {
		wolfSSL_CTX_free(c);
		return NULL;
	}
	fprintf(stderr, "[dbg] groups set OK\n");
	return c;
}

TLS_CTX *tls_ctx_new_server(const char *cert_file, const char *key_file) {
	WOLFSSL_CTX *c = mk_ctx_common(/*is_server=*/1);
	if (!c)
		return NULL;

	// Load ML-DSA (Dilithium / ML-DSA) certificate and key in PEM
	if (wolfSSL_CTX_use_certificate_file(c, cert_file, WOLFSSL_FILETYPE_PEM) !=
			WOLFSSL_SUCCESS ||
		wolfSSL_CTX_use_PrivateKey_file(c, key_file, WOLFSSL_FILETYPE_PEM) !=
			WOLFSSL_SUCCESS) {
		fprintf(stderr, "[wolfssl] load cert/key failed\n");
		wolfSSL_CTX_free(c);
		return NULL;
	}
	TLS_CTX *r = (TLS_CTX *)calloc(1, sizeof(*r));
	if (!r) {
		wolfSSL_CTX_free(c);
		return NULL;
	}
	r->ctx = c;
	return r;
}

TLS_CTX *tls_ctx_new_client(void) {
	WOLFSSL_CTX *c = mk_ctx_common(/*is_server=*/0);
	if (!c)
		return NULL;

	// Trust our demo CA by default (same certs as OpenSSL demo)
	// If you place CA elsewhere, change the path or expose via env.
	if (wolfSSL_CTX_load_verify_locations(c, "cert/ca.crt", NULL) !=
		WOLFSSL_SUCCESS) {
		fprintf(stderr, "[wolfssl] load CA failed (cert/ca.crt)\n");
		wolfSSL_CTX_free(c);
		return NULL;
	}
	wolfSSL_CTX_set_verify(c, WOLFSSL_VERIFY_PEER, NULL);

	TLS_CTX *r = (TLS_CTX *)calloc(1, sizeof(*r));
	if (!r) {
		wolfSSL_CTX_free(c);
		return NULL;
	}
	r->ctx = c;
	return r;
}

void tls_ctx_free(TLS_CTX *ctx) {
	if (!ctx)
		return;
	wolfSSL_CTX_free(ctx->ctx);
	free(ctx);
}

TLS *tls_new(TLS_CTX *ctx, int fd) {
	TLS *t = (TLS *)calloc(1, sizeof(*t));
	if (!t)
		return NULL;
	t->ssl = wolfSSL_new(ctx->ctx);
	if (!t->ssl) {
		free(t);
		return NULL;
	}
	t->fd = fd;
	wolfSSL_set_fd(t->ssl, fd);

	// Critical: pick *pure* ML-KEM-768 for KeyShare (no hybrid).
	if (wolfSSL_UseKeyShare(t->ssl, WOLFSSL_ML_KEM_768) != WOLFSSL_SUCCESS) {
		fprintf(stderr, "[wolfssl] UseKeyShare(ML_KEM_768) failed\n");
		wolfSSL_free(t->ssl);
		free(t);
		return NULL;
	}
	return t;
}

int tls_accept(TLS *t) {
	return wolfSSL_accept(t->ssl) == WOLFSSL_SUCCESS ? 0 : -1;
}
int tls_connect(TLS *t) {
	return wolfSSL_connect(t->ssl) == WOLFSSL_SUCCESS ? 0 : -1;
}

ssize_t tls_read(TLS *t, void *buf, size_t len) {
	int n = wolfSSL_read(t->ssl, buf, (int)len);
	return n;
}

ssize_t tls_write(TLS *t, const void *buf, size_t len) {
	int n = wolfSSL_write(t->ssl, buf, (int)len);
	return n;
}

void tls_close(TLS *t) {
	if (!t)
		return;
	wolfSSL_shutdown(t->ssl);
	wolfSSL_free(t->ssl);
	close(t->fd);
	free(t);
}
