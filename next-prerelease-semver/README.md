# example semver util

```sh
podman build -t quay.io/trevorbox/next-prerelease-semver:latest .
podman run -it --privileged --mount type=bind,source=./,target=/tmp/auth/ quay.io/trevorbox/next-prerelease-semver:latest /bin/bash -c "/opt/app-root/next-prerelease-semver --repository=docker.io/trevorbox/go-app --release=1.2.1 --authfile=/tmp/auth/auth.json"
podman push quay.io/trevorbox/next-prerelease-semver:latest
```
