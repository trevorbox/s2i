# Java S2I Example

A S2I example for building a Java application without ImageStreams.

The BuildConfig pulls a base S2I builder image from, and then pushes the built image back to, Quay.

## Example BuildConfig

Create a robot account in Quay and give it write access to a desired push repository and read to a desired pull repository.

> Note: my example uses the same robot account, but you could use two different account to keep the push vs pull credentials separate.

```sh
export docker_credentials_file=<robot account docker config.json file location>
export namespace=java-sample
oc new-project ${namespace}
oc create secret generic my-pull-secret \
    --from-file=.dockercfg=${docker_credential_file} \
    --type=kubernetes.io/dockercfg -n ${namespace}
oc create secret generic my-push-secret \
    --from-file=.dockercfg=${docker_credential_file} \
    --type=kubernetes.io/dockercfg -n ${namespace}
helm upgrade -i java-sample helm/java-sample -n ${namespace}
```
