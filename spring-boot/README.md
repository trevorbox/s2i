# spring-boot

build with JRE from microdnf
```sh
docker build -t test-dnf -f Dockerfile.micro --build-arg BUILD_ENV=dnf .
```

build from jre tarball (download it locally) 
> <https://developers.redhat.com/content-gateway/file/openjdk/21.0.3/java-21-openjdk-21.0.3.0.9-1.portable.jre.x86_64.tar.xz>
```sh
docker build -t test-local -f Dockerfile.micro --build-arg BUILD_ENV=local .
```
