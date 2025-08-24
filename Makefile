# ---- toolchain ---------------------------------------------------------------
CC      ?= cc
CSTD    ?= -std=c11
CFLAGS  ?= -O2 -Wall -Wextra
CPPFLAGS+= -Iinclude

# ---- OpenSSL 3.5 location (override by: make OPENSSL_PREFIX=/path/to/ossl-3.5)
OPENSSL_PREFIX ?= $(HOME)/opt/openssl-3.5
# Prefer lib64 if present, otherwise lib
OPENSSL_LIBDIR  := $(shell if [ -d "$(OPENSSL_PREFIX)/lib64" ]; then echo "$(OPENSSL_PREFIX)/lib64"; else echo "$(OPENSSL_PREFIX)/lib"; fi)

# Link against 3.5 libs and embed RPATH so runtime uses them
LDFLAGS += -L$(OPENSSL_LIBDIR) -Wl,-rpath,$(OPENSSL_LIBDIR)
LDLIBS  += -lssl -lcrypto

# ---- sources -----------------------------------------------------------------
SRCS_SERVER = src/server.c backends/openssl/tls_backend.c
SRCS_CLIENT = src/client.c backends/openssl/tls_backend.c
OBJS_SERVER = $(SRCS_SERVER:.c=.o)
OBJS_CLIENT = $(SRCS_CLIENT:.c=.o)

# ---- default -----------------------------------------------------------------
.PHONY: all
all: server client

# ---- build rules --------------------------------------------------------------
server: $(OBJS_SERVER)
	$(CC) $(OBJS_SERVER) $(LDFLAGS) $(LDLIBS) -o $@

client: $(OBJS_CLIENT)
	$(CC) $(OBJS_CLIENT) $(LDFLAGS) $(LDLIBS) -o $@

%.o: %.c
	$(CC) $(CPPFLAGS) $(CSTD) $(CFLAGS) -c $< -o $@

# ---- helpers -----------------------------------------------------------------
.PHONY: clean print-vars run-demo
clean:
	rm -f src/*.o backends/*/*.o server client tests/test_tls

print-vars:
	@echo "OPENSSL_PREFIX=$(OPENSSL_PREFIX)"
	@echo "OPENSSL_LIBDIR=$(OPENSSL_LIBDIR)"

# Quick demo (adds OPENSSL_MODULES for provider discovery)
run-demo: server client
	OPENSSL_MODULES="$(OPENSSL_LIBDIR)/ossl-modules" ./server & pid=$$!; \
	sleep 1; \
	printf "hello\n" | OPENSSL_MODULES="$(OPENSSL_LIBDIR)/ossl-modules" ./client; \
	kill $$pid || true
