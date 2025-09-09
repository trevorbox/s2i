# To build, run the following command from the top level project directory:
#
# docker build -f src/main/docker/Dockerfile .

ARG BUILD_ENV=container

FROM registry.access.redhat.com/ubi9/openjdk-21:latest as build-container
USER 0
WORKDIR /application
COPY src src
COPY pom.xml .
RUN mvn package 
RUN java -Djarmode=layertools -jar target/*.jar extract
# CRYOSTAT
RUN cp target/dependency/cryostat-agent-shaded.jar /application/dependencies/

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:latest as build-local
USER 0
WORKDIR /application
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} application.jar
RUN java -Djarmode=layertools -jar application.jar extract && chown -R 1001:0 /application && \
    chmod -R g=u /application

FROM build-${BUILD_ENV} as intermediate

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:latest
USER 1001
WORKDIR /application
COPY --from=intermediate /application/dependencies/ ./
COPY --from=intermediate /application/spring-boot-loader/ ./
COPY --from=intermediate /application/snapshot-dependencies/ ./
COPY --from=intermediate /application/application/ ./

CMD ["java", "-javaagent:cryostat-agent-shaded.jar", "org.springframework.boot.loader.launch.JarLauncher"]
# CMD ["java", "-Dcom.sun.management.jmxremote.port=9091", "-Dcom.sun.management.jmxremote.ssl=false", "-Dcom.sun.management.jmxremote.authenticate=false", "org.springframework.boot.loader.launch.JarLauncher"]
