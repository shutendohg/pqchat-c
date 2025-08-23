TLS_BACKEND ?= openssl

CFLAGS = -std=c11 -O2 -Wall -Wextra -Iinclude
LDFLAGS =

ifeq ($(TLS_BACKEND), openssl)
	CFLAGS += $(shell pkg-config --cflags openssl)
	LDFLAGS += $(shell pkg-config --libs openssl)
	BACKEND_SRC = backends/openssl/tls_backend.c
	BACKEND_OBJ = $(BACKEND_SRC:.c=.o)
else
	$(error Unsupported TLS_BACKEND=$(TLS_BACKEND))
endif

all: server client
server: src/server.o $(BACKEND_OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)
client: src/client.o $(BACKEND_OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)
clean:
	rm -rf src/*.o backends/*/*.o server client tests/test_tls
.PHONY: all clean test-unit

test-unit: tests/test_tls
	./tests/test_tls

tests/test_tls: tests/test_tls.c backends/openssl/tls_backend.openssl
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS)
