FROM registry.access.redhat.com/ubi8/nodejs-14 as builder
USER 0
ADD angular-test /tmp/src
RUN chown -R 1001:0 /tmp/src
USER 1001
RUN /usr/libexec/s2i/assemble

FROM registry.access.redhat.com/ubi8/nginx-120
USER 0
ADD nginx-default-cfg /tmp/src/nginx-default-cfg/
COPY --from=builder /opt/app-root/src/dist/angular-test /tmp/src/
RUN chown -R 1001:0 /tmp/src
USER 1001
# Let the assemble script to install the dependencies
RUN /usr/libexec/s2i/assemble
# Run script uses standard ways to run the application
CMD /usr/libexec/s2i/run
