# spring-boot

<https://docs.spring.io/spring-boot/reference/packaging/container-images/dockerfiles.html>

## Local build and test

The project targets **Java 21** bytecode and language level (`java.version` 21 in `pom.xml`, compiled with **`--release 21`**). You can build and test on any machine where **the JDK used to run Maven is version 21 or newer** (for example JDK 21, 22, or 25). The Maven Enforcer plugin rejects older runtimes (below 21).

**Use a full JDK** that includes a working `javac`, not a runtime-only or broken headless image. On Fedora/RHEL, install the development package and point tools at it, for example:

```sh
sudo dnf install java-21-openjdk-devel
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
```

Confirm:

```sh
java -version
"$JAVA_HOME/bin/javac" -version
```

Then from this directory:

```sh
./mvnw clean package    # compile, run tests, build the Spring Boot jar
./mvnw test             # tests only
```

If compilation fails with **`error: release version 21 not supported`** even though `java -version` shows 21 or higher, your install may be **headless-only** or ship a `javac` that does not advertise any supported `--release` versions. Install a **`devel`** JDK as above, or as a workaround for that environment only:

```sh
./mvnw clean package -DcompatJavac
```

That activates the `compat-headless-javac` Maven profile (see `pom.xml`), which compiles with **`-source 21` / `-target 21`** instead of `--release 21`. The profile also passes **`-Xlint:-options`** so `javac` does not print the usual "system modules" cross-compilation warning for that mode. For tests, Surefire is given JVM flags (**JDK 23+** required for all of them to be accepted) to reduce noise from Tomcat JNI, Netty / Guava `Unsafe`, and Mockito's ByteBuddy agent. Prefer a normal full JDK for day-to-day development so you get the stricter API checks that `--release 21` provides.

**Maven JVM stderr (not your app):** On newer JDKs, `./mvnw` may still print warnings from libraries embedded in Maven (for example Jansi native access on JDK 22+, or Guava and `sun.misc.Unsafe` on JDK 24+). Those come from the **JDK that runs Maven**, not from this project’s compile flags. You can optionally silence many of them by creating **`.mvn/jvm.config`** next to this README (only add lines your JDK accepts; unknown options will make `java` fail to start):

```text
--enable-native-access=ALL-UNNAMED
```

JDK **23+** also accepts:

```text
--sun-misc-unsafe-memory-access=allow
```

Alternatively set the same tokens in **`MAVEN_OPTS`** instead of using `.mvn/jvm.config`.

---

> Note: using --build-arg BUILD_ENV=local will copy over the locally built jar (`./mvnw package`) vs building in a container

build using registry.access.redhat.com/ubi9/openjdk-21-runtime:latest as final layer

```sh
podman build -t ubi9-openjdk-21 -f Dockerfile .
podman run -it --rm -p 8080:8080 ubi9-openjdk-21 
```

build using registry.access.redhat.com/hi/openjdk:21-runtime as final layer

```sh
podman build -t hi-openjdk-21 -f Dockerfile . --build-arg FINAL_RUNTIME=hi
podman run -it --rm -p 8080:8080 hi-openjdk-21
```

build with openjdk-headless

```sh
podman build -t micro-jdk-headless -f Dockerfile --build-arg FINAL_RUNTIME=micro --build-arg MICRO_RUNTIME=headless .
podman run -it --rm -p 8080:8080 micro-jdk-headless
```

build from jre tarball (download it locally) <https://developers.redhat.com/content-gateway/file/openjdk/21.0.12.1/java-21-openjdk-21.0.12.1.1-1.0.portable.jre.x86_64.tar.xz>

```sh
podman build -t micro-jre -f Dockerfile --build-arg FINAL_RUNTIME=micro --build-arg MICRO_RUNTIME=jre-local .
podman run -it --rm -p 8080:8080 micro-jre
```

analysis from final layer content

```sh
[tbox@fedora spring-boot]$ podman images
REPOSITORY                                          TAG         IMAGE ID      CREATED        SIZE
localhost/micro-jre                                 latest      a45201aadebb  3 minutes ago  284 MB
localhost/micro-jdk-headless                        latest      ad6328bf0e2e  4 minutes ago  424 MB
localhost/hi-openjdk-21                             latest      ba494e25430d  4 minutes ago  328 MB
localhost/ubi9-openjdk-21                           latest      c0cfad757e5d  5 minutes ago  472 MB
```

```sh
skopeo copy containers-storage:localhost/micro-jre:latest docker://quay.io/trevorbox/spring-boot-micro-jre:latest
skopeo copy containers-storage:localhost/micro-jdk-headless:latest docker://quay.io/trevorbox/spring-boot-micro-jdk-headless:latest
skopeo copy containers-storage:localhost/ubi9-openjdk-21:latest docker://quay.io/trevorbox/spring-boot-ubi9-openjdk-21:latest
skopeo copy containers-storage:localhost/hi-openjdk-21:latest docker://quay.io/trevorbox/spring-boot-hi-openjdk-21:latest
```

```sh
helm upgrade -i spring-boot-demo-micro-jre helm/spring-boot-demo --create-namespace --set image.repository=quay.io/trevorbox/spring-boot-micro-jre -n spring-boot-demo
helm upgrade -i spring-boot-demo-micro-jdk-headless helm/spring-boot-demo --create-namespace --set image.repository=quay.io/trevorbox/spring-boot-micro-jdk-headless -n spring-boot-demo
helm upgrade -i spring-boot-demo-ubi9-openjdk-21 helm/spring-boot-demo --create-namespace --set image.repository=quay.io/trevorbox/spring-boot-ubi9-openjdk-21 -n spring-boot-demo
```

## Tracing (OpenTelemetry)

Istio can stamp each request with W3C (`traceparent`) or B3 headers. Those spans are the HTTP hop only. This app continues that trace and adds method spans plus the original caller.

`GET /api/work?sku=widget` runs three child spans: `work.authorize`, `work.lookup-order`, and `work.price`. The response includes `traceId` (same id as the incoming `traceparent`) and `enduser.id` when the caller is known.

The original caller is the W3C baggage key `enduser.id`. If that key is absent, the app copies the `X-End-User` header into baggage for this request and for outbound calls. A later hop keeps the baggage it received. The value is a span attribute and a logging MDC field, and it is not a Prometheus label.

```sh
curl -s -H 'X-End-User: ada' \
  -H 'traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01' \
  'http://localhost:8080/api/work?sku=widget'
```

Search the trace backend for `4bf92f3577b34da6a3ce929d0e0e4736`, not Envoy's `x-request-id`.

OTLP export is **off** by default (`management.tracing.export.otlp.enabled=false`), so the process does not dial a collector. Spans and `enduser.id` are still created, and incoming `traceparent` / B3 headers are still continued. Metrics stay on `/actuator/prometheus`. Turn export on with `MANAGEMENT_TRACING_EXPORT_OTLP_ENABLED=true`. The traces URL defaults to `http://localhost:4318/v1/traces` and can be overridden with `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`.

Local process, with a collector on the host:

```sh
podman run --rm -p 4318:4318 -p 16686:16686 docker.io/jaegertracing/all-in-one:1.62.0

MANAGEMENT_TRACING_EXPORT_OTLP_ENABLED=true ./mvnw spring-boot:run
```

The Jaeger UI is at <http://localhost:16686>. Search for the `traceId` from the JSON response.

Podman app container. `localhost` inside that container is not the host, so put both containers on one network and point at the collector by name:

```sh
podman network create tracing
podman run --rm --name jaeger --network tracing \
  -p 4318:4318 -p 16686:16686 docker.io/jaegertracing/all-in-one:1.62.0

podman run -it --rm --network tracing -p 8080:8080 \
  -e MANAGEMENT_TRACING_EXPORT_OTLP_ENABLED=true \
  -e OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://jaeger:4318/v1/traces \
  ubi9-openjdk-21
```

Helm. Leave `tracing.enabled` false for a normal install. To export app spans to the same collector the mesh uses:

```sh
helm upgrade -i spring-boot-demo helm/spring-boot-demo \
  --set tracing.enabled=true \
  --set tracing.otlpEndpoint=http://otel-collector.observability.svc:4318/v1/traces
```

Sampling follows the parent. An unsampled `traceparent` from Istio drops the app spans even though `management.tracing.sampling.probability` is `1.0`. For a demo namespace, set the mesh `Telemetry` `randomSamplingPercentage` to `100` on the provider already configured under `extensionProviders` (the name below has to match that provider). `customTags` only decorates the Envoy span; the method spans come from the app.

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: otel-demo
  namespace: spring-boot-demo
spec:
  tracing:
  - randomSamplingPercentage: 100
    providers:
    - name: otel-tracing
    customTags:
      enduser.id:
        header:
          name: x-end-user
```

`/live`, `/ready`, and `/actuator/**` are not traced. `X-End-User` is spoofable; a real edge should set it from a verified token and strip any client-supplied value.

## Graceful shutdown (native sidecar)

On OpenShift Service Mesh 3 / Istio native sidecars, Envoy stays up until **this process exits**. Istio `POST /drain` only GOAWAYs new connections; it does not finish in-flight work or wait for Istiod EDS. Configure the **application pod**, not `holdApplicationUntilProxyStarts` or `terminationDrainDuration` (leave both unset on apps). Details: [`native-sidecar-drain-test/README.md`](../../openshift-service-mesh/components/native-sidecar-drain-test/README.md).

This app:

* `server.shutdown=graceful` — on SIGTERM, refuse new requests, finish in-flight work, then exit (`spring.lifecycle.timeout-per-shutdown-phase=30s`).
* `GET /ready` — 503 when `/tmp/unhealthy` exists **or** Spring readiness is `REFUSING_TRAFFIC`. `GET /live` stays 200 so kubelet does not SIGKILL mid-drain.
* `GET /sleep?seconds=` — blocking in-flight request for drain tests.

The Helm chart (`terminationGracePeriodSeconds: 40` > 5s preStop + 30s Tomcat drain):

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "touch /tmp/unhealthy; sleep 5"]
readinessProbe:
  httpGet: { path: /ready, port: http }
  periodSeconds: 1
livenessProbe:
  httpGet: { path: /live, port: http }
```

`preStop` is a **single** exec: fail readiness **first**, then sleep (EDS cushion). Sleep alone leaves Ready=true; failing `/ready` only on SIGTERM is too late (after `preStop`). Rolling updates use `maxUnavailable: 0` so a Ready replacement exists before the old pod is deleted.

Drain check from an in-mesh client: `GET /sleep?seconds=8`, then delete the pod, expect HTTP 200.

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
