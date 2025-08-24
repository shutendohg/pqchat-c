#include "tls_backend.h"
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

struct tls_ctx {
  SSL_CTX *ctx;
};
struct tls {
  SSL *ssl;
  int fd;
};

static SSL_CTX *mk_ctx_common(void) {
  SSL_CTX *c = SSL_CTX_new(TLS_method()); // TLS汎用
  if (!c)
    return NULL;
  SSL_CTX_set_min_proto_version(c, TLS1_3_VERSION);
  fprintf(stderr, "[dbg] about to set groups: MLKEM768\n");
  if (!SSL_CTX_set1_groups_list(c, "MLKEM768")) {
    fprintf(stderr, "[openssl] set group MLKEM768 failed\n");
    ERR_print_errors_fp(stderr);
    SSL_CTX_free(c);
    return NULL;
  }
  fprintf(stderr, "[dbg] groups set OK\n");
  return c;
}

TLS_CTX *tls_ctx_new_server(const char *cert_file, const char *keyfile) {
  SSL_CTX *c = mk_ctx_common();
  if (!c)
    return NULL;
  if (SSL_CTX_use_certificate_file(c, cert_file, SSL_FILETYPE_PEM) <= 0 ||
      SSL_CTX_use_PrivateKey_file(c, keyfile, SSL_FILETYPE_PEM) <= 0 ||
      !SSL_CTX_check_private_key(c)) {
    fprintf(stderr, "[openssl] load cert.key filed \n");
    SSL_CTX_free(c);
    return NULL;
  }
  TLS_CTX *r = (TLS_CTX *)malloc(sizeof(*r));
  if (!r) {
    SSL_CTX_free(c);
    return NULL;
  }
  r->ctx = c;
  return r;
}
TLS_CTX *tls_ctx_new_client(void) {
  SSL_CTX *c = mk_ctx_common();
  if (!c)
    return NULL;
  TLS_CTX *r = (TLS_CTX *)malloc(sizeof(*r));
  if (!r) {
    SSL_CTX_free(c);
    return NULL;
  }
  /* Validate Server certification if there is cert/ca.crt */
  if (access("cert/ca.crt", R_OK) == 0) {
    if (SSL_CTX_load_verify_locations(c, "cert/ca.crt", NULL) != 1) {
      fprintf(stderr, "[openssl] load CA faield\n");
      ERR_print_errors_fp(stderr);
      SSL_CTX_free(c);
      free(r);
      return NULL;
    }
    SSL_CTX_set_verify(c, SSL_VERIFY_PEER, NULL);
  }
  r->ctx = c;
  return r;
}

void tls_ctx_free(TLS_CTX *ctx) {
  if (!ctx)
    return;
  SSL_CTX_free(ctx->ctx);
  free(ctx);
}

TLS *tls_new(TLS_CTX *ctx, int fd) {
  TLS *t = (TLS *)calloc(1, sizeof(*t));
  if (!t)
    return NULL;
  t->ssl = SSL_new(ctx->ctx);
  t->fd = fd;
  SSL_set_fd(t->ssl, fd);
  return t;
}

int tls_accept(TLS *t) { return SSL_accept(t->ssl) > 0 ? 0 : -1; }
int tls_connect(TLS *t) { return SSL_connect(t->ssl) > 0 ? 0 : -1; }

ssize_t tls_read(TLS *t, void *buf, size_t len) {
  int n = SSL_read(t->ssl, buf, (int)len);
  return n;
}
ssize_t tls_write(TLS *t, const void *buf, size_t len) {
  int n = SSL_write(t->ssl, buf, (int)len);
  return n;
}

void tls_close(TLS *t) {
  if (!t)
    return;
  SSL_shutdown(t->ssl);
  SSL_free(t->ssl);
  close(t->fd);
  free(t);
}
