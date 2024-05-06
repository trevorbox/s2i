# spring-boot

build with JRE from microdnf

```sh
podman build -t micro-jdk-headless -f Dockerfile.micro --build-arg BUILD_ENV=dnf .
```

build from jre tarball (download it locally) 
> <https://developers.redhat.com/content-gateway/file/openjdk/21.0.3/java-21-openjdk-21.0.3.0.9-1.portable.jre.x86_64.tar.xz>

```sh
podman build -t micro-jre -f Dockerfile.micro --build-arg BUILD_ENV=local .
```

build using registry.access.redhat.com/ubi9/openjdk-21-runtime:latest as final layer

```sh
podman build -t ubi9-openjdk-21 -f Dockerfile --build-arg BUILD_ENV=container .
```

analysis from final layer content

```sh
[tbox@fedora spring-boot]$ docker images
REPOSITORY           TAG       IMAGE ID       CREATED          SIZE
ubi9-openjdk-21      latest    937ba1070101   5 seconds ago    392MB
micro-jre            latest    ee11ee1c7601   35 seconds ago   241MB
micro-jdk-headless   latest    f65c23258130   45 seconds ago   359MB
```