# Install the app dependencies in a full Node docker image
FROM registry.access.redhat.com/ubi8/nodejs-14-minimal:latest
USER root
# Copying in source code
COPY app /tmp/src
COPY .s2i /usr/libexec/s2i
# Change file ownership to the assemble user. Builder image must support chown command.
RUN chown -R 1001:0 /tmp/src && chown -R 1001:0 /usr/libexec/s2i/assemble && chmod +x /usr/libexec/s2i/assemble
USER 1001
# Assemble script sourced from builder image based on user input or image metadata.
# If this file does not exist in the image, the build will fail.
RUN /usr/libexec/s2i/assemble
CMD /usr/libexec/s2i/run
