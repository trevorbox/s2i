# Install the app dependencies in a full Node docker image
FROM registry.access.redhat.com/ubi8/go-toolset:latest AS builder
USER root
# Copying in source code
COPY app /tmp/src
# Change file ownership to the assemble user. Builder image must support chown command.
RUN chown -R 1001:0 /tmp/src
USER 1001
# Assemble script sourced from builder image based on user input or image metadata.
# If this file does not exist in the image, the build will fail.
RUN /usr/libexec/s2i/assemble

# Copy the dependencies into a minimal Node docker image
FROM registry.access.redhat.com/ubi8/ubi-micro:latest
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
