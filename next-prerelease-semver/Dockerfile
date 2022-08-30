# Install the app dependencies in a full Node docker image
FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder
USER root
# Copying in source code
COPY main.go /tmp/src/
COPY go.mod /tmp/src/
COPY go.sum /tmp/src/
# Change file ownership to the assemble user. Builder image must support chown command.
RUN chown -R 1001:0 /tmp/src
USER 1001
# Assemble script sourced from builder image based on user input or image metadata.
# If this file does not exist in the image, the build will fail.
RUN /usr/libexec/s2i/assemble

FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

ARG YQ_VERSION=v4.27.3

ARG YQ_BINARY=yq_linux_amd64

USER root

RUN microdnf install -y skopeo && \
  microdnf clean all -y && \
  curl -L https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY} -o /usr/bin/yq && \
  chmod +x /usr/bin/yq && \
  rm -rf /var/cache/yum

WORKDIR "/opt/app-root"
# Install app dependencies
COPY --from=builder /opt/app-root/gobinary next-prerelease-semver

CMD /opt/app-root/next-prerelease-semver
