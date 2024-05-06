# To build, run the following command from the top level project directory:
#
# docker build -f src/main/docker/Dockerfile .

ARG BUILD_ENV=container

FROM registry.access.redhat.com/ubi9/openjdk-17:latest as build-container
WORKDIR /application
COPY src src
COPY pom.xml .
RUN mvn clean package && java -Djarmode=layertools -jar target/*.jar extract

FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest as build-local
WORKDIR /application
ARG JAR_FILE=/target/*.jar
COPY ${JAR_FILE} application.jar
RUN java -Djarmode=layertools -jar application.jar extract

FROM build-${BUILD_ENV} as intermediate

FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest
WORKDIR /application
COPY --from=intermediate /application/dependencies/ ./
COPY --from=intermediate /application/spring-boot-loader/ ./
COPY --from=intermediate /application/snapshot-dependencies/ ./
COPY --from=intermediate /application/application/ ./
ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
