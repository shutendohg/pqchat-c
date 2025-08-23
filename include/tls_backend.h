#ifndef TLS_BACKEND_H
#define TLS_BACKEND_H
#include <stddef.h>
#include <sys/types.h>

typedef struct tls_ctx TLS_CTX;
typedef struct tls TLS;

TLS_CTX *tls_ctx_new_server(const char *cert_file, const char *keyfile);
TLS_CTX *tls_ctx_new_client(void);
void tls_ctx_free(TLS_CTX *ctx);

TLS *tls_new(TLS_CTX *ctx, int fd);
int tls_accept(TLS *t);  // server side handshake
int tls_connect(TLS *t); // client side handshake
ssize_t tls_read(TLS *t, void *buf, size_t len);
ssize_t tls_write(TLS *t, const void *buf, size_t len);
void tls_close(TLS *t);

#endif
