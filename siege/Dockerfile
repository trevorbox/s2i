# Stage 1: Build binary
FROM registry.access.redhat.com/ubi9/ubi:latest AS builder

ARG SIEGE_VERSION=4.1.7

RUN dnf install -y gcc make openssl-devel zlib-devel tar gzip && \
    curl -fsSL "http://download.joedog.org/siege/siege-${SIEGE_VERSION}.tar.gz" -o /tmp/siege.tar.gz && \
    tar -xzf /tmp/siege.tar.gz -C /tmp && \
    cd /tmp/siege-${SIEGE_VERSION} && \
    ./configure --prefix=/usr/local --with-ssl && \
    make && \
    make install

# Stage 2: Minimal runtime
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

RUN microdnf install -y openssl-libs zlib shadow-utils && \
    microdnf clean all

COPY --from=builder /usr/local/bin/siege /usr/local/bin/siege
COPY --from=builder /usr/local/etc /usr/local/etc

USER 1001

ENTRYPOINT ["siege"]
CMD ["--help"]