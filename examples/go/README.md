# Example multi-stage build to produce a minimal go image

> Note: example application code in the [app/](./app/) folder taken from <https://github.com/sclorg/golang-ex.git>

This demonstrates a multi-stage build using the registry.access.redhat.com/ubi8/go-toolset builder and registry.access.redhat.com/ubi8/micro images which produces an image much smaller than a typical s2i build.

Build...

```sh
podman build . -t golang-ex
```

Run...

```sh
podman run -it -p 8080:8080 golang-ex
```

Below demonstrates the final image size...

```sh
[tbox@localhost go]$ podman images
REPOSITORY                                   TAG      IMAGE ID       CREATED              SIZE
localhost/golang-ex                          latest   5e99b2b0cb85   54 seconds ago       52.7 MB
<none>                                       <none>   0137df945940   About a minute ago   1.12 GB
registry.access.redhat.com/ubi8/go-toolset   latest   81acb0c94986   5 weeks ago          1.11 GB
registry.access.redhat.com/ubi8/ubi-micro    latest   f390b26f6a00   6 weeks ago          39.1 MB
```
