# httpd server to broadcast oidc info from kube api

```sh
podman build . -t httpd
podman run -it --rm --name httpd -p 8080:8080 httpd
podman exec -it httpd bash

```

```sh
helm upgrade -i httpd charts/httpd -n default
```
