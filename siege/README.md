# Siege

```sh
podman build -t ubi9-siege .
podman run --rm -it ubi9-siege -c 20 -t 30s https://httpbin.org/get
skopeo copy containers-storage:localhost/ubi9-siege:latest docker://quay.io/trevorbox/ubi9-siege:latest
```
