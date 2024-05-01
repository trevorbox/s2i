# $(skopeo inspect --format "{{ .Digest }}" docker://registry.access.redhat.com/ubi9/go-toolset:latest)
ARG builder_image_digest
# example: registry.access.redhat.com/ubi9/go-toolset
ARG builder_image_repository
# $(skopeo inspect --format "{{ .Digest }}" docker://registry.access.redhat.com/ubi9/ubi-micro:latest)
ARG base_image_digest
# example: registry.access.redhat.com/ubi9/ubi-micro
ARG base_image_repository

# builder image
FROM ${builder_image_repository}@${builder_image_digest} AS builder

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

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG builder_image_digest
ARG builder_image_repository
ARG base_image_digest
ARG base_image_repository

# Copy the dependencies into a minimal Node docker image
FROM ${base_image_repository}@${base_image_digest}

ARG builder_image_digest
ARG builder_image_repository
ARG builder_image_tag

ARG base_image_digest
ARG base_image_repository
ARG base_image_tag

# $(git config --get remote.origin.url)
ARG git_origin_url
# $(git rev-parse HEAD)
ARG git_revision
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
    org.opencontainers.image.base.name=${base_image_repository}:${base_image_tag} \
    org.opencontainers.image.version=${src_version} \
    org.opencontainers.image.created=${created} \
    org.opencontainers.image.authors=${author_emails} \    
    com.example.org.context.build-host=${build_host} \
    com.example.org.context.build-id=${build_id} \
    com.example.org.context.image.builder.digest=${builder_image_digest} \
    com.example.org.context.image.builder.name=${builder_image_repository}:${builder_image_tag}

USER root
WORKDIR "/opt/app-root"
# Install app dependencies
COPY --from=builder /opt/app-root/gobinary .
# Copy over run script
COPY .s2i /usr/libexec/s2i
# Change file ownership to the assemble user. Builder image must support chown command.
RUN chown -R 1001:0 . && chown -R 1001:0 /usr/libexec/s2i && chmod +x /usr/libexec/s2i/run
USER 1001

EXPOSE 8080
# Run script sourced from builder image based on user input or image metadata.
# If this file does not exist in the image, the build will fail.
CMD /usr/libexec/s2i/run
