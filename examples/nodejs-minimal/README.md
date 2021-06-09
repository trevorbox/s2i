# Example multi-stage build to produce a minimal nodejs image

> Note: example application code in the [app/](./app/) folder taken from <https://github.com/sclorg/nodejs-ex.git>

This demonstrates a multi-stage build using the nodejs-14 builder and minimal images which produces an image much smaller than a typical s2i build.

Build...

```sh
podman build . -t nodejs-ex
```

Run...

```sh
podman run -it -p 8080:8080 nodejs-ex
```

Below demonstrates the final image size...

```sh
[tbox@localhost nodejs]$ podman images
REPOSITORY                                          TAG      IMAGE ID       CREATED              SIZE
localhost/nodejs-ex                                 latest   c96b917495ae   About a minute ago   220 MB
<none>                                              <none>   35d681b4ae9d   2 minutes ago        640 MB
registry.access.redhat.com/ubi8/nodejs-14-minimal   latest   bfa627e124e9   5 weeks ago          203 MB
registry.access.redhat.com/ubi8/nodejs-14           latest   7e83665d8f0d   5 weeks ago          632 MB
```
