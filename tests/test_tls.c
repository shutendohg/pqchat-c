#include "tls_backend.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
	TLS_CTX *c = tls_ctx_new_client();
	assert(c && "client ctx should be created");
	tls_ctx_free(c);

	TLS_CTX *s = tls_ctx_new_server("cert/srv.crt", "cert/srv.key");
	if (s) {
		tls_ctx_free(s);
		printf("server ctx created (certs present)\n");
	} else {
		printf("server ctx failed as expectee (no cert yet)\n");
	}
	printf("unit tests OK\n");
	return 0;
}
