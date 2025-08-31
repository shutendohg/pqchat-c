# ---- toolchain ---------------------------------------------------------------
CC      ?= cc
CSTD    ?= -std=c11
CFLAGS  ?= -O2 -Wall -Wextra
CPPFLAGS+= -Iinclude

# ---- backend selector --------------------------------------------------------
#   make                # default: openssl
#   make BACKEND=wolfssl
BACKEND ?= openssl

# ---- OpenSSL 3.5 location (used when BACKEND=openssl) ------------------------
# Override by: make OPENSSL_PREFIX=/path/to/ossl-3.5
OPENSSL_PREFIX ?= $(HOME)/opt/openssl-3.5
OPENSSL_LIBDIR  := $(shell if [ -d "$(OPENSSL_PREFIX)/lib64" ]; then echo "$(OPENSSL_PREFIX)/lib64"; else echo "$(OPENSSL_PREFIX)/lib"; fi)

ifeq ($(BACKEND),openssl)
  # Use headers from our OpenSSL prefix
  CPPFLAGS += -I$(OPENSSL_PREFIX)/include
  # Link against 3.5 libs and embed RPATH so runtime uses them
  LDFLAGS  += -L$(OPENSSL_LIBDIR) -Wl,-rpath,$(OPENSSL_LIBDIR)
  LDLIBS   += -lssl -lcrypto
endif

# ---- wolfSSL location (used when BACKEND=wolfssl) ----------------------------
# Override by: make BACKEND=wolfssl WOLFSSL_PREFIX=/opt/wolfssl
WOLFSSL_PREFIX ?= /usr/local
WOLFSSL_LIBDIR  := $(shell if [ -d "$(WOLFSSL_PREFIX)/lib64" ]; then echo "$(WOLFSSL_PREFIX)/lib64"; else echo "$(WOLFSSL_PREFIX)/lib"; fi)

ifeq ($(BACKEND),wolfssl)
  # Try pkg-config first with an augmented PKG_CONFIG_PATH
  PKGCF            := PKG_CONFIG_PATH=$(WOLFSSL_PREFIX)/lib/pkgconfig:$(WOLFSSL_PREFIX)/lib64/pkgconfig pkg-config
  WOLFSSL_CFLAGS   := $(shell $(PKGCF) --cflags wolfssl 2>/dev/null)
  WOLFSSL_LIBS     := $(shell $(PKGCF) --libs   wolfssl 2>/dev/null)
  # Headers (include flags usually come via CFLAGS/CPPFLAGS)
  CPPFLAGS += $(WOLFSSL_CFLAGS)
  # Link flags: prefer pkg-config, otherwise fallback to manual -L/-lwolfssl + RPATH
  ifneq ($(strip $(WOLFSSL_LIBS)),)
    LDLIBS  += $(WOLFSSL_LIBS)
  else
    LDFLAGS += -L$(WOLFSSL_LIBDIR) -Wl,-rpath,$(WOLFSSL_LIBDIR)
    LDLIBS  += -lwolfssl
  endif
endif

# ---- sources -----------------------------------------------------------------
BACKEND_SRC  := backends/$(BACKEND)/tls_backend.c
SRCS_SERVER  := src/server.c $(BACKEND_SRC)
SRCS_CLIENT  := src/client.c $(BACKEND_SRC)
OBJS_SERVER  := $(SRCS_SERVER:.c=.o)
OBJS_CLIENT  := $(SRCS_CLIENT:.c=.o)

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
.PHONY: clean print-vars run-demo gen-certs
clean:
	rm -f src/*.o backends/*/*.o server client tests/test_tls

print-vars:
	@echo "BACKEND         = $(BACKEND)"
	@echo "OPENSSL_PREFIX  = $(OPENSSL_PREFIX)"
	@echo "OPENSSL_LIBDIR  = $(OPENSSL_LIBDIR)"
	@echo "WOLFSSL_PREFIX  = $(WOLFSSL_PREFIX)"
	@echo "WOLFSSL_LIBDIR  = $(WOLFSSL_LIBDIR)"
	@echo "PKG_CONFIG_PATH = $(WOLFSSL_PREFIX)/lib/pkgconfig:$(WOLFSSL_PREFIX)/lib64/pkgconfig"
	@echo "WOLFSSL_CFLAGS  = $(WOLFSSL_CFLAGS)"
	@echo "WOLFSSL_LIBS    = $(WOLFSSL_LIBS)"

# Generate ML-DSA/ML-KEM demo certs if missing (uses OpenSSL CLI)
gen-certs:
	@if [ ! -f cert/srv.crt ]; then \
	  echo "[gen-certs] generating demo certificates (ML-DSA-65)"; \
	  mkdir -p cert; \
	  OPENSSL=$(OPENSSL_PREFIX)/bin/openssl OPENSSL_CONF=$(PWD)/openssl.cnf ./scripts/gen_certs.sh; \
	else \
	  echo "[gen-certs] certs already exist; skipping"; \
	fi

# Quick local demo
# - For BACKEND=openssl: ensures provider discovery via OPENSSL_MODULES
# - For BACKEND=wolfssl: no special envs required
run-demo: all gen-certs
ifeq ($(BACKEND),openssl)
	OPENSSL_MODULES="$(OPENSSL_LIBDIR)/ossl-modules" ./server & pid=$$!; \
	sleep 1; \
	printf "hello\n" | OPENSSL_MODULES="$(OPENSSL_LIBDIR)/ossl-modules" ./client; \
	kill $$pid || true
else
	./server & pid=$$!; \
	sleep 1; \
	printf "hello\n" | ./client; \
	kill $$pid || true
endif
