#include "tls_backend.h"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <openssl/err.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define PORT 4433
#define BUF 4096

int main(int argc, char **argv) {
  const char *host = (argc > 1) ? argv[1] : "::1";
  TLS_CTX *ctx = tls_ctx_new_client();
  if (!ctx)
    return 1;

  int s = socket(AF_INET6, SOCK_STREAM, 0);
  if (s < 0) {
    perror("socket");
    return 1;
  }
  struct sockaddr_in6 a = {0};
  a.sin6_family = AF_INET6;
  if (inet_pton(AF_INET6, host, &a.sin6_addr) != 1) {
    perror("inet_pton");
    return 1;
  }
  a.sin6_port = htons(PORT);
  if (connect(s, (struct sockaddr *)&a, sizeof(a)) < 0) {
    perror("connect");
    return 1;
  }

  TLS *t = tls_new(ctx, s);
  if (!t || tls_connect(t) != 0) {
    fprintf(stderr, "connect fail\n");
    if (t)
      tls_close(t);
    else
      close(s);
    tls_ctx_free(ctx);
    return 1;
  }

  char buf[BUF];
  int one_shot = !isatty(STDIN_FILENO);
  while (fgets(buf, sizeof(buf), stdin)) {
    int len = (int)strlen(buf);
    if (tls_write(t, buf, (size_t)len) <= 0) {
      fprintf(stderr, "tls_write\n");
      break;
    }
    int n = (int)tls_read(t, buf, sizeof(buf) - 1);
    if (n <= 0)
      break;
    buf[n] = 0;
    printf("echo: %s", buf);
    if (one_shot)
      break;
  }
  tls_close(t);
  tls_ctx_free(ctx);
  return 0;
}
