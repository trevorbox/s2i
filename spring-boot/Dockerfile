# To build, run the following command from the top level project directory:
#
# docker build -f src/main/docker/Dockerfile .

ARG BUILD_ENV=container
ARG FINAL_IMAGE=registry.access.redhat.com/ubi9/openjdk-21-runtime:latest
# ARG FINAL_IMAGE=registry.access.redhat.com/hi/openjdk:21-runtime

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

FROM ${FINAL_IMAGE}
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
