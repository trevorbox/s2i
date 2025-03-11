# Example multi-stage build to produce a minimal go image

> Note: example application code in the [app/](./app/) folder taken from <https://github.com/sclorg/golang-ex.git>

This demonstrates a multi-stage build using the registry.access.redhat.com/ubi8/go-toolset builder and registry.access.redhat.com/ubi8/micro images which produces an image much smaller than a typical s2i build.

Build with ubi-micro...

```sh
export TAG="quay.io/trevorbox/golang-ex:v2" # replace with your tag

podman build -t $TAG . \
  --build-arg git_origin_url=$(git config --get remote.origin.url) \
  --build-arg git_revision=$(git rev-parse HEAD) \
  --build-arg builder_image_digest=$(skopeo inspect --format "{{ .Digest }}" docker://registry.access.redhat.com/ubi9/go-toolset:latest) \
  --build-arg builder_image_repository=registry.access.redhat.com/ubi9/go-toolset \
  --build-arg builder_image_tag=latest \
  --build-arg base_image_digest=$(skopeo inspect --format "{{ .Digest }}" docker://registry.access.redhat.com/ubi9/ubi-micro:latest) \
  --build-arg base_image_repository=registry.access.redhat.com/ubi9/ubi-micro \
  --build-arg base_image_tag=latest \
  --build-arg src_version=$(git rev-parse --abbrev-ref HEAD) \
  --build-arg created=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg author_emails="myorg@example.com" \
  --build-arg build_host=$(uname -n) \
  --build-arg build_id="1337" 
```

Run...

```sh
podman run -it -p 8080:8080 golang-ex
```

build/run with scratch...

```sh
podman build -f Dockerfile.scratch -t golang-ex-scratch . \
  --build-arg git_origin_url=$(git config --get remote.origin.url) \
  --build-arg git_revision=$(git rev-parse HEAD) \
  --build-arg builder_image_digest=$(skopeo inspect --format "{{ .Digest }}" docker://registry.access.redhat.com/ubi9/go-toolset:latest) \
  --build-arg builder_image_repository=registry.access.redhat.com/ubi9/go-toolset \
  --build-arg builder_image_tag=latest \
  --build-arg src_version=$(git rev-parse --abbrev-ref HEAD) \
  --build-arg created=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg author_emails="myorg@example.com" \
  --build-arg build_host=$(uname -n) \
  --build-arg build_id="1337"
podman run --rm -it -p 8080:8080 golang-ex-scratch:latest
```

Below demonstrates the final image sizes...

```sh
[tbox@fedora go]$ podman images -f label=org.opencontainers.image.title
REPOSITORY                   TAG         IMAGE ID      CREATED        SIZE
localhost/golang-ex-scratch  latest      dcce4f987791  2 minutes ago  4.81 MB
<none>                       <none>      f21fad1ad572  2 minutes ago  4.93 kB
localhost/golang-ex          latest      a4da6132b5a1  3 minutes ago  38.2 MB
```

# openshift build

Create a robot account in Quay and give it write access to a desired push repository and read to a desired pull repository.

> Note: my example uses the same robot account, but you could use two different account to keep the push vs pull credentials separate.

```sh
export docker_credentials_file=<robot account docker config.json file location>
export namespace=test
helm upgrade -i go-app-build helm/go-app-build -n ${namespace} --create-namespace \
  --set-file imagePushSecret=${docker_credentials_file} 
```

# deploy

```sh
helm upgrade --create-namespace -i golang-ex helm/golang-ex -n golang-ex
helm upgrade -i go-app helm/go-app-deploy -n ${namespace} --create-namespace \
  --set nameOverride=go-app \
  --set ingress.hosts[0].host=go-app-${namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain}) \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="ImplementationSpecific"
```
