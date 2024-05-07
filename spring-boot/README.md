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

```sh
skopeo copy containers-storage:localhost/micro-jre:latest docker://quay.io/trevorbox/spring-boot-micro-jre:latest
skopeo copy containers-storage:localhost/micro-jdk-headless:latest docker://quay.io/trevorbox/spring-boot-micro-jdk-headless:latest
skopeo copy containers-storage:localhost/ubi9-openjdk-21:latest docker://quay.io/trevorbox/spring-boot-ubi9-openjdk-21:latest
```

```sh
helm upgrade -i spring-boot-demo-micro-jre helm/spring-boot-demo --create-namespace --set image.repository=quay.io/trevorbox/spring-boot-micro-jre -n spring-boot-demo
helm upgrade -i spring-boot-demo-micro-jdk-headless helm/spring-boot-demo --create-namespace --set image.repository=quay.io/trevorbox/spring-boot-micro-jdk-headless -n spring-boot-demo
helm upgrade -i spring-boot-demo-ubi9-openjdk-21 helm/spring-boot-demo --create-namespace --set image.repository=quay.io/trevorbox/spring-boot-ubi9-openjdk-21 -n spring-boot-demo
```

```sh
oc exec deploy/spring-boot-demo-micro-jdk-headless -- java -XshowSettings:system -version && java -Xlog:gc=info -version
oc exec deploy/spring-boot-demo-micro-jre -- java -XshowSettings:system -version && java -Xlog:gc=info -version
oc exec deploy/spring-boot-demo-ubi9-openjdk-21 -- java -XshowSettings:system -version && java -Xlog:gc=info -version
```

Take a look at differences <https://developers.redhat.com/articles/2022/04/19/java-17-whats-new-openjdks-container-awareness#recent_changes_in_openjdk_s_container_awareness_code>

All appear to behave similarly...

```sh
[tbox@fedora spring-boot]$ oc exec deploy/spring-boot-demo-micro-jdk-headless -- java -XshowSettings:system -version && java -Xlog:gc=info -version
oc exec deploy/spring-boot-demo-micro-jre -- java -XshowSettings:system -version && java -Xlog:gc=info -version
oc exec deploy/spring-boot-demo-ubi9-openjdk-21 -- java -XshowSettings:system -version && java -Xlog:gc=info -version
Operating System Metrics:
    Provider: cgroupv2
    Effective CPU Count: 6
    CPU Period: 100000us
    CPU Quota: -1
    CPU Shares: 1024us
    List of Processors: N/A
    List of Effective Processors, 6 total: 
    0 1 2 3 4 5 
    List of Memory Nodes: N/A
    List of Available Memory Nodes, 1 total: 
    0 
    Memory Limit: 3.00G
    Memory Soft Limit: 0.00K
    Memory & Swap Limit: 3.00G
    Maximum Processes Limit: 204843

openjdk version "21.0.3" 2024-04-16 LTS
OpenJDK Runtime Environment (Red_Hat-21.0.3.0.9-1) (build 21.0.3+9-LTS)
OpenJDK 64-Bit Server VM (Red_Hat-21.0.3.0.9-1) (build 21.0.3+9-LTS, mixed mode, sharing)
[0.002s][info][gc] Using G1
openjdk version "21.0.2" 2024-01-16
OpenJDK Runtime Environment (Red_Hat-21.0.2.0.13-2) (build 21.0.2+13)
OpenJDK 64-Bit Server VM (Red_Hat-21.0.2.0.13-2) (build 21.0.2+13, mixed mode, sharing)
Operating System Metrics:
    Provider: cgroupv2
    Effective CPU Count: 6
    CPU Period: 100000us
    CPU Quota: -1
    CPU Shares: 1024us
    List of Processors: N/A
    List of Effective Processors, 6 total: 
    0 1 2 3 4 5 
    List of Memory Nodes: N/A
    List of Available Memory Nodes, 1 total: 
    0 
    Memory Limit: 3.00G
    Memory Soft Limit: 0.00K
    Memory & Swap Limit: 3.00G
    Maximum Processes Limit: 204843

openjdk version "21.0.3" 2024-04-16 LTS
OpenJDK Runtime Environment (Red_Hat-21.0.3.0.9-1) (build 21.0.3+9-LTS)
OpenJDK 64-Bit Server VM (Red_Hat-21.0.3.0.9-1) (build 21.0.3+9-LTS, mixed mode, sharing)
[0.002s][info][gc] Using G1
openjdk version "21.0.2" 2024-01-16
OpenJDK Runtime Environment (Red_Hat-21.0.2.0.13-2) (build 21.0.2+13)
OpenJDK 64-Bit Server VM (Red_Hat-21.0.2.0.13-2) (build 21.0.2+13, mixed mode, sharing)
Operating System Metrics:
    Provider: cgroupv2
    Effective CPU Count: 6
    CPU Period: 100000us
    CPU Quota: -1
    CPU Shares: 1024us
    List of Processors: N/A
    List of Effective Processors, 6 total: 
    0 1 2 3 4 5 
    List of Memory Nodes: N/A
    List of Available Memory Nodes, 1 total: 
    0 
    Memory Limit: 3.00G
    Memory Soft Limit: 0.00K
    Memory & Swap Limit: 3.00G
    Maximum Processes Limit: 204843

openjdk version "21.0.3" 2024-04-16 LTS
OpenJDK Runtime Environment (Red_Hat-21.0.3.0.9-1) (build 21.0.3+9-LTS)
OpenJDK 64-Bit Server VM (Red_Hat-21.0.3.0.9-1) (build 21.0.3+9-LTS, mixed mode, sharing)
[0.002s][info][gc] Using G1
openjdk version "21.0.2" 2024-01-16
OpenJDK Runtime Environment (Red_Hat-21.0.2.0.13-2) (build 21.0.2+13)
OpenJDK 64-Bit Server VM (Red_Hat-21.0.2.0.13-2) (build 21.0.2+13, mixed mode, sharing)
```