#include "tls_backend.h"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <sys/socket.h>
#include <unistd.h>

#define PORT 4433
#define BUF 4096

static int listen6_any(void) {
  int s = socket(AF_INET6, SOCK_STREAM, 0);
  if (s < 0) {
    perror("socket");
    return -1;
  }
  int off = 0;
  setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, &off, sizeof(off));
  struct sockaddr_in6 a = {0};
  a.sin6_family = AF_INET6;
  a.sin6_addr = in6addr_any;
  a.sin6_port = htons(PORT);
  if (bind(s, (struct sockaddr *)&a, sizeof(a)) < 0) {
    perror("bind");
    close(s);
    return -1;
  }
  if (listen(s, 16) < 0) {
    perror("listen");
    close(s);
    return -1;
  }
  return s;
}

int main(void) {
  setvbuf(stdout, NULL, _IONBF, 0);
  setvbuf(stderr, NULL, _IONBF, 0);
  fprintf(stderr, "[dbg] main entered\n");

  TLS_CTX *ctx = tls_ctx_new_server("cert/srv.crt", "cert/srv.key");
  if (!ctx) {
    fprintf(stderr, "tls_ctx_new_server failed(cert didn't generated?)\n");
    return 1;
  }
  fprintf(stderr, "[dbg] tls_ctx_new_server OK\n");

  fprintf(stderr, "[dbg] calling listen6_any\n");
  int ls = listen6_any();
  if (ls < 0) {
    fprintf(stderr, "[dbg] listen6_any failed\n");
    return 1;
  }

  fprintf(stderr, "🔒 PQ-TLS server : %d (KEM=MLKEM768)\n",
          PORT); /* stderrへ */
  for (;;) {
    int cs = accept(ls, NULL, NULL);
    if (cs < 0) {
      perror("accept");
      continue;
    }
    TLS *t = tls_new(ctx, cs);
    if (!t || tls_accept(t) != 0) {
      fprintf(stderr, "handshake fail\n");
      if (t)
        tls_close(t);
      else
        close(cs);
      continue;
    }
    char buf[BUF];
    int n;
    while ((n = (int)tls_read(t, buf, sizeof(buf))) > 0) {
      tls_write(t, buf, (size_t)n);
      fwrite(buf, 1, n, stdout);
      fflush(stdout);
    }
    tls_close(t);
  }
}
