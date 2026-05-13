ARG BUILD_ENV=container
# ARG BUILD_ENV=local
ARG FINAL_RUNTIME=ubi
# ARG FINAL_RUNTIME=hi
# ARG FINAL_RUNTIME=micro
ARG MICRO_RUNTIME=headless
# ARG MICRO_RUNTIME=jre-local

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:latest AS runtime-ubi
FROM registry.access.redhat.com/hi/openjdk:21-runtime AS runtime-hi

##### BEGIN ubi micro runtime packaging #####
FROM registry.access.redhat.com/ubi9/ubi-micro:latest as micro

FROM registry.access.redhat.com/ubi9/ubi-minimal:latest as micro-headless
COPY --from=micro / /install-root
ARG DNF_OPTS="--installroot=/install-root --setopt=reposdir=/install-root/etc/yum.repos.d/ --setopt=cachedir=/install-cache/ --setopt=varsdir= --config= --noplugins"
RUN microdnf --nodocs --best --assumeyes --setopt=install_weak_deps=0 install tar gzip unzip
RUN microdnf ${DNF_OPTS} \
  --nodocs --best --assumeyes --setopt=install_weak_deps=0 \
  install java-21-openjdk-headless && microdnf ${DNF_OPTS} clean all && rm /install-root/var/lib/dnf/history*

FROM registry.access.redhat.com/ubi9/ubi-minimal:latest as micro-jre-local
COPY --from=micro / /install-root
RUN mkdir -p /jdks && mkdir -p /install-root/jdks/java-21
# youll need to download this file locally
ADD java-21-openjdk-21.0.11.0.10-1.portable.jre.x86_64.tar.xz /jdks
RUN mv /jdks/*/* /install-root/jdks/java-21

FROM micro-${MICRO_RUNTIME} as micro-with-jre

FROM registry.access.redhat.com/ubi9/ubi-micro:latest as runtime-micro
COPY --from=micro-with-jre /install-root /
ENV JAVA_HOME=/jdks/java-21
ENV PATH=/jdks/java-21/bin:$PATH
##### END ubi micro runtime packaging #####

FROM registry.access.redhat.com/ubi9/openjdk-21:latest as build-container
USER 0
WORKDIR /builder
COPY src src
COPY pom.xml .
RUN mvn package 
RUN mv target/*.jar target/application.jar
RUN java -Djarmode=tools -jar target/*.jar extract --layers --destination extracted
# CRYOSTAT
RUN cp target/dependency/cryostat-agent-shaded.jar /builder/extracted/dependencies/

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:latest as build-local
USER 0
WORKDIR /builder
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} application.jar
RUN java -Djarmode=tools -jar application.jar extract --layers --destination extracted

FROM build-${BUILD_ENV} as intermediate

FROM runtime-${FINAL_RUNTIME}
WORKDIR /application
USER 1001
COPY --from=intermediate \
     /builder/extracted/dependencies/ \
     /builder/extracted/spring-boot-loader/ \
     /builder/extracted/snapshot-dependencies/ \
     /builder/extracted/application/ \
     ./
# ENV JAVA_TOOL_OPTIONS="-javaagent:cryostat-agent-shaded.jar"
ENTRYPOINT ["java", "-jar", "application.jar"]
