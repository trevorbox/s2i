# http11 / Istio upgrade header repro and fix

Reproduces [istio/istio#53239](https://github.com/istio/istio/issues/53239): cleartext `http://` mesh requests with `Upgrade: TLS/1.2` get **403** (`upgrade_failed`) from Envoy instead of reaching the backend.

## Reproduce (spring-boot-demo)

```sh
oc exec -n spring-boot-demo deploy/spring-boot-demo -c spring-boot-demo -- \
  curl -sv \
    -H "Connection: Upgrade" \
    -H "Upgrade: TLS/1.2" \
    http://spring-boot-demo.spring-boot-demo.svc.cluster.local:8080/
```

Expect **403** with `server: envoy`. Sidecar logs: `upgrade_failed`.

HTTPS ingress URLs do **not** reproduce this; use in-mesh `http://...svc.cluster.local` as above.

## Fix with EnvoyFilter (Envoy >= 1.34)

`ignore_http_11_upgrade` strips matching upgrade headers and forwards the request normally ([envoy#37642](https://github.com/envoyproxy/envoy/pull/37642)).

Apply the workload-scoped filter (spring-boot-demo pods only):

```sh
oc apply -f envoyfilter-spring-boot-demo.yaml
oc rollout restart deploy/spring-boot-demo -n spring-boot-demo
```

Re-run the curl test; expect **200**.

Remove:

```sh
oc delete -f envoyfilter-spring-boot-demo.yaml
oc rollout restart deploy/spring-boot-demo -n spring-boot-demo
```

### Via Helm (spring-boot chart)

```sh
helm upgrade spring-boot-demo ../spring-boot/helm/spring-boot-demo -n spring-boot-demo \
  --set istio.envoyFilter.ignoreHttp11Upgrade.enabled=true
oc rollout restart deploy/spring-boot-demo -n spring-boot-demo
```

## Verify Envoy version

```sh
oc exec -n spring-boot-demo deploy/spring-boot-demo -c istio-proxy -- \
  /usr/local/bin/envoy --version
```

`ignore_http_11_upgrade` requires **Envoy 1.34.0+**.
