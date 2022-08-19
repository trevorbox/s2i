# Install the app dependencies in a full Node docker image
FROM registry.access.redhat.com/ubi8/go-toolset:latest AS builder
USER root
# Copying in source code
COPY main.go /tmp/src/
COPY go.mod /tmp/src/
# Change file ownership to the assemble user. Builder image must support chown command.
RUN chown -R 1001:0 /tmp/src
USER 1001
# Assemble script sourced from builder image based on user input or image metadata.
# If this file does not exist in the image, the build will fail.
RUN /usr/libexec/s2i/assemble

# Copy the dependencies into a minimal Node docker image
FROM registry.access.redhat.com/ubi8/ubi-micro:latest

# $(git config --get remote.origin.url)
ARG git_origin_url
# $(git rev-parse HEAD)
ARG git_revision
# $(skopeo inspect --format "{{ .Digest }}" docker://registry.access.redhat.com/ubi8/go-toolset:latest)
ARG base_image_digest
# $(skopeo inspect --format "{{ .Name }}" docker://registry.access.redhat.com/ubi8/go-toolset:latest)
ARG base_image_name
# $(git rev-parse --abbrev-ref HEAD)
# note: this is a a semver git tag typically
ARG src_version
# ${date -u +'%Y-%m-%dT%H:%M:%SZ'}
ARG created
# group emails of the team that supports this image
ARG author_emails
# the build host url
ARG build_host
# a unique id for the build of this image
ARG build_id

LABEL org.opencontainers.image.title=go-app \
    org.opencontainers.image.description="An example multi-stage build for go." \
    org.opencontainers.image.source=${git_origin_url} \
    org.opencontainers.image.revision=${git_revision} \
    org.opencontainers.image.base.digest=${base_image_digest} \
    org.opencontainers.image.base.name=${base_image_name} \
    org.opencontainers.image.version=${src_version} \
    org.opencontainers.image.created=${created} \
    org.opencontainers.image.authors=${author_emails} \    
    com.example.org.context.build-host=${build_host} \
    com.example.org.context.build-id=${build_id}

USER root
WORKDIR "/opt/app-root"
# Install app dependencies
COPY --from=builder /opt/app-root/gobinary .
# Copy over run script
COPY .s2i /usr/libexec/s2i
# Change file ownership to the assemble user. Builder image must support chown command.
RUN chown -R 1001:0 . && chown -R 1001:0 /usr/libexec/s2i && chmod +x /usr/libexec/s2i/run
USER 1001
# Run script sourced from builder image based on user input or image metadata.
# If this file does not exist in the image, the build will fail.
CMD /usr/libexec/s2i/run
