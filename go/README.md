# Example multi-stage build to produce a minimal go image

> Note: example application code in the [app/](./app/) folder taken from <https://github.com/sclorg/golang-ex.git>

This demonstrates a multi-stage build using the registry.access.redhat.com/ubi8/go-toolset builder and registry.access.redhat.com/ubi8/micro images which produces an image much smaller than a typical s2i build.

Build...

```sh
podman build -t golang-ex . \
  --build-arg git_origin_url=$(git config --get remote.origin.url) \
  --build-arg git_revision=$(git rev-parse HEAD) \
  --build-arg base_image_digest=$(skopeo inspect --format "{{ .Digest }}" docker://registry.access.redhat.com/ubi8/ubi-micro:latest) \
  --build-arg base_image_repository=registry.access.redhat.com/ubi8/ubi-micro
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

Below demonstrates the final image size...

```sh
[tbox@localhost go]$ podman images
REPOSITORY                                   TAG      IMAGE ID       CREATED              SIZE
localhost/golang-ex                          latest   5e99b2b0cb85   54 seconds ago       52.7 MB
<none>                                       <none>   0137df945940   About a minute ago   1.12 GB
registry.access.redhat.com/ubi8/go-toolset   latest   81acb0c94986   5 weeks ago          1.11 GB
registry.access.redhat.com/ubi8/ubi-micro    latest   f390b26f6a00   6 weeks ago          39.1 MB
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
helm upgrade -i go-app helm/go-app-deploy -n ${namespace} --create-namespace \
  --set nameOverride=go-app \
  --set ingress.hosts[0].host=go-app-${namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain}) \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType="ImplementationSpecific"
```
