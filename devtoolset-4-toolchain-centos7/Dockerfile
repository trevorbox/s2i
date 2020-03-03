# s2i-devtoolset-4-toolchain-centos7
FROM openshift/base-centos7

LABEL maintainer="Trevor Box <tbox@redhat.com>"

ENV BUILDER_VERSION devtoolset-4-toolchain-centos7

LABEL io.k8s.description="Platform for building C++ Apps" \
      io.k8s.display-name="builder devtoolset-4-toolchain-centos7" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,devtoolset-4-toolchain-centos7"

RUN yum install -y \
  make \
  fontconfig-devel \
  freetype-devel \
  mesa-libGL-devel \
  pax \
  && yum clean all -y

# Copy the builder files into /opt/app-root
# COPY ./tmp/src /opt/app-root/

# Copy the S2I scripts to /usr/libexec/s2i, since openshift/base-centos7 image
# sets io.openshift.s2i.scripts-url label that way, or update that label
COPY ./s2i/bin/ /usr/libexec/s2i

# Drop the root user and make the content of /opt/app-root owned by user 1001
# RUN chown -R 1001:1001 /opt/app-root

# This default user is created in the openshift/base-centos7 image
USER 1001

# Set the default port for applications built using this image
# EXPOSE 8080

CMD ["/usr/libexec/s2i/usage"]
