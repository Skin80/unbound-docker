# Stage 1: Build environment
FROM alpine:3.19 AS builder

# Define Unbound version (latest stable as of Feb 2026)
ENV UNBOUND_VERSION=1.24.2

# Install build dependencies
RUN apk add --no-cache \
    curl build-base openssl-dev expat-dev libevent-dev

# Download and compile Unbound
RUN curl -sSL https://nlnetlabs.nl/downloads/unbound/unbound-latest.tar.gz -o unbound.tar.gz && \
    tar xzf unbound.tar.gz && \
    cd unbound-*/ && \
    ./configure --prefix=/usr --sysconfdir=/etc --with-libevent && \
    make -j$(nproc) && \
    make install

# Download default root hints file
RUN curl -sSL https://www.internic.net -o /etc/unbound/root.hints

# Stage 2: Production image
FROM alpine:3.19

# Install runtime dependencies only
RUN apk add --no-cache \
    openssl expat libevent ca-certificates

# Copy compiled binaries and default configs from builder
COPY --from=builder /usr/sbin/unbound /usr/sbin/unbound
COPY --from=builder /usr/sbin/unbound-checkconf /usr/sbin/unbound-checkconf
COPY --from=builder /usr/sbin/unbound-control /usr/sbin/unbound-control
COPY --from=builder /etc/unbound /etc/unbound

# Create an unprivileged user to run Unbound
RUN adduser -D -s /sbin/nologin unbound && \
    mkdir -p /etc/unbound && \
    chown -R unbound:unbound /etc/unbound

USER unbound
EXPOSE 53/udp 53/tcp

CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
