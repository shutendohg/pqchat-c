#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

#define PORT 4444

int create_socket(char* host, int port) {
	int s;
	struct sockaddr_in addr;

	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	addr.sin_addr.s_addr = inet_addr(host);

	s = socket(AF_INET, SOCK_STREAM, 0);
	if (s < 0) {
		perror("Unable to create socket");
		exit(EXIT_FAILURE);
	}

	if (connect(s, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
		perror("Unable to connect");
		exit(EXIT_FAILURE);
	}

	return s;
}

void init_openssl() {
	SSL_load_error_strings();
	OpenSSL_add_ssl_algorithms();
}

void cleanup_openssl() {
	EVP_cleanup();
}

SSL_CTX *create_context() {
	const SSL_METHOD *method;
	SSL_CTX *ctx;

	method = SSLv23_client_method();

	ctx = SSL_CTX_new(method);
	if (!ctx) {
		perror("Unable to create SSL context");
		ERR_print_errors_fp(stderr);
		exit(EXIT_FAILURE);
	}

	return ctx;
}

void configure_context(SSL_CTX *ctx) {
	SSL_CTX_set_default_verify_paths(ctx);
}

int main(int argc, char **argv) {
	int sock;
	SSL_CTX *ctx;

	init_openssl();
	ctx = create_context();
	configure_context(ctx);

	sock = create_socket("127.0.0.1", PORT);

	SSL *ssl = SSL_new(ctx);
	SSL_set_fd(ssl, sock);

	if (SSL_connect(ssl) == -1) {
		ERR_print_errors_fp(stderr);
	} else {
		char *msg = "Hello, this is a secure message.";
		int bytes = SSL_write(ssl, msg, strlen(msg));

		if (bytes > 0) {
			printf("Message sent to server: %s\n", msg);
			char buf[1024] = {0};
			bytes = SSL_read(ssl, buf, sizeof(buf));
			if(bytes > 0) {
				printf("Received from server: %s\n", buf);
			}
		}
	}

	SSL_free(ssl);
	close(sock);
	SSL_CTX_free(ctx);
	cleanup_openssl();

	return 0;
}