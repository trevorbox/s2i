#!/usr/bin/env bash
# Dump an Envoy / istio-proxy heap profile via the admin API (GET /heap_dump).
#
# OSSM / Istio proxy images usually have no curl or tar; this uses pilot-agent
# request and copies the profile out with base64. pilot-agent appends a trailing
# newline to stdout — this script strips it so gzip/pprof can read the file.
#
# Run: ./envoy-proxy-heap-dump.sh --help

set -euo pipefail

usage() {
  local prog
  prog="$(basename "$0")"
  cat <<USAGE >&2
Dump an Envoy heap profile from an istio-proxy (or other Envoy) sidecar.

Usage:
  $prog [--help] [--memory] [--keep-remote] [OUTPUT_FILE]

Arguments:
  OUTPUT_FILE       Local path for the heap profile (default: ./envoy.heap)

Options:
  -h, --help        Show this message and exit.
  --memory          Also print GET /memory JSON to stderr.
  --keep-remote     Do not delete the profile file inside the pod.

Environment:
  NS                Namespace (default: spring-boot-demo)
  POD               Pod name (required unless POD_AUTO=1)
  POD_AUTO=1        Use first Running pod in NS (order not guaranteed)
  PROXY_C           Sidecar container name (default: istio-proxy)
  REMOTE_DIR        Writable directory in the proxy container
                    (default: auto — tries /var/lib/istio/data then /tmp)

Examples:
  NS=spring-boot-demo POD_AUTO=1 $prog
  NS=spring-boot-demo POD=my-pod-abc $prog ./proxy.heap
  $prog --memory ./envoy.heap

After a successful run, the script prints steps to view the profile with go tool pprof.
USAGE
}

MEMORY=0
KEEP_REMOTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --memory)
      MEMORY=1
      shift
      ;;
    --keep-remote)
      KEEP_REMOTE=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

OUT="${1:-./envoy.heap}"
if [[ $# -gt 1 ]]; then
  echo "Too many arguments (expected at most one output path)." >&2
  usage
  exit 2
fi

NS="${NS:-spring-boot-demo}"
PROXY_C="${PROXY_C:-istio-proxy}"
POD_AUTO="${POD_AUTO:-0}"

if ! command -v oc >/dev/null 2>&1; then
  echo "oc not found in PATH" >&2
  exit 1
fi

proxy_exec() {
  oc exec -n "$NS" "$POD" -c "$PROXY_C" -- "$@"
}

admin_request() {
  local method=$1 path=$2
  proxy_exec pilot-agent request "$method" "$path"
}

resolve_pod() {
  if [[ -n "${POD:-}" ]]; then
    return 0
  fi
  if [[ "$POD_AUTO" == "1" ]]; then
    POD="$(oc get pods -n "$NS" -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' | head -1)"
    if [[ -z "$POD" ]]; then
      echo "POD_AUTO=1 but no Running pod found in namespace $NS" >&2
      exit 1
    fi
    echo "Using pod: $POD" >&2
    return 0
  fi
  echo "Set POD to the target pod name, or POD_AUTO=1. Example:" >&2
  echo "  POD=\$(oc get pods -n $NS -o jsonpath='{.items[0].metadata.name}') $0 $OUT" >&2
  echo "Run: $(basename "$0") --help" >&2
  exit 1
}

verify_pod_and_proxy() {
  if ! oc get pod -n "$NS" "$POD" >/dev/null 2>&1; then
    echo "Pod not found: $NS/$POD" >&2
    exit 1
  fi
  local containers init_containers
  containers="$(oc get pod -n "$NS" "$POD" -o jsonpath='{.spec.containers[*].name}')"
  init_containers="$(oc get pod -n "$NS" "$POD" -o jsonpath='{.spec.initContainers[*].name}')"
  if [[ " $containers $init_containers " != *" $PROXY_C "* ]]; then
    echo "Container \"$PROXY_C\" not found on pod $POD (containers: ${containers:-none}; initContainers: ${init_containers:-none})" >&2
    exit 1
  fi
  if ! proxy_exec test -x /usr/local/bin/pilot-agent 2>/dev/null; then
    echo "pilot-agent not found in $PROXY_C — cannot call Envoy admin API (is the proxy still running?)" >&2
    exit 1
  fi
}

resolve_remote_dir() {
  if [[ -n "${REMOTE_DIR:-}" ]]; then
    if ! proxy_exec sh -c "touch '$REMOTE_DIR/.write-test-$$' && rm -f '$REMOTE_DIR/.write-test-$$'"; then
      echo "REMOTE_DIR is not writable in $PROXY_C: $REMOTE_DIR" >&2
      exit 1
    fi
    echo "$REMOTE_DIR"
    return 0
  fi
  proxy_exec sh -c '
    for d in /var/lib/istio/data /tmp; do
      if touch "$d/.write-test-$$" 2>/dev/null; then
        rm -f "$d/.write-test-$$"
        echo "$d"
        exit 0
      fi
    done
    echo "no writable directory under /var/lib/istio/data or /tmp" >&2
    exit 1
  '
}

strip_pilot_agent_newline() {
  local raw=$1 final=$2
  local sz last_byte
  sz=$(wc -c <"$raw" | tr -d ' ')
  if [[ "$sz" -eq 0 ]]; then
    echo "Downloaded heap profile is empty" >&2
    return 1
  fi
  last_byte=$(tail -c 1 "$raw" | xxd -p 2>/dev/null || true)
  if [[ "$last_byte" == "0a" ]]; then
    truncate -s $((sz - 1)) "$raw"
  fi
  mv -f "$raw" "$final"
}

validate_profile() {
  if command -v gzip >/dev/null 2>&1; then
    if ! gzip -t "$OUT" 2>/dev/null; then
      echo "Warning: $OUT does not look like valid gzip (pilot-agent or admin API issue?)" >&2
      return 0
    fi
  fi
  if command -v go >/dev/null 2>&1; then
    if go tool pprof -top "$OUT" >/dev/null 2>&1; then
      echo "pprof: profile OK" >&2
    else
      echo "Warning: go tool pprof could not read $OUT" >&2
    fi
  fi
}

print_view_instructions() {
  local out_abs out_dir prof_dir envoy_bin
  out_abs="$(realpath "$OUT" 2>/dev/null || echo "$OUT")"
  out_dir="$(dirname "$out_abs")"
  prof_dir="${out_dir}/.pprof/usr/local/bin"
  envoy_bin="${prof_dir}/envoy"

  cat >&2 <<EOF

--- View heap profile ---
Prerequisites:
  - Go (go tool pprof)
  - graphviz (dot) for Graph / Flame Graph views in the web UI

1. Copy the envoy binary from this pod (once per proxy image version):
   mkdir -p ${prof_dir}
   oc exec -n ${NS} ${POD} -c ${PROXY_C} -- base64 /usr/local/bin/envoy \\
     | base64 -d > ${envoy_bin} && chmod +x ${envoy_bin}

2. Interactive web UI:
   go tool pprof -http localhost:9999 ${envoy_bin} ${out_abs}
   Open http://localhost:9999 — use Top for a summary; Graph / Flame Graph need graphviz.

3. Quick CLI summary:
   go tool pprof -top ${envoy_bin} ${out_abs}

4. Compare growth since a baseline capture:
   go tool pprof -http localhost:9999 -base old.heap ${envoy_bin} ${out_abs}

Notes:
  - OSSM envoy binaries are stripped; stacks show as [envoy], not function names.
  - Profile size is sampled tcmalloc heap, not full RSS. Live memory:
      oc exec -n ${NS} ${POD} -c ${PROXY_C} -- pilot-agent request GET /memory
EOF
}

REMOTE_HEAP=""
cleanup_remote() {
  if [[ "$KEEP_REMOTE" == "1" || -z "$REMOTE_HEAP" ]]; then
    return 0
  fi
  proxy_exec rm -f "$REMOTE_HEAP" 2>/dev/null || true
}

resolve_pod
verify_pod_and_proxy

REMOTE_DIR="$(resolve_remote_dir)"
REMOTE_HEAP="${REMOTE_DIR}/envoy-heap-dump.$$"

trap cleanup_remote EXIT

if [[ "$MEMORY" == "1" ]]; then
  echo "--- GET /memory ($NS/$POD:$PROXY_C) ---" >&2
  admin_request GET /memory >&2
  echo >&2
fi

echo "Dumping heap profile to $NS/$POD:$PROXY_C:$REMOTE_HEAP ..." >&2
if ! proxy_exec sh -c "pilot-agent request GET /heap_dump > '$REMOTE_HEAP' 2>/dev/null"; then
  echo "pilot-agent request GET /heap_dump failed" >&2
  exit 1
fi

REMOTE_SIZE="$(proxy_exec sh -c "wc -c < '$REMOTE_HEAP'" | tr -d ' ')"
if [[ -z "$REMOTE_SIZE" || "$REMOTE_SIZE" -eq 0 ]]; then
  echo "Heap dump file is empty on the pod" >&2
  exit 1
fi
echo "Remote size: ${REMOTE_SIZE} bytes" >&2

TMP_RAW="$(mktemp)"
trap 'rm -f "$TMP_RAW"; cleanup_remote' EXIT

if ! proxy_exec base64 "$REMOTE_HEAP" | base64 -d >"$TMP_RAW"; then
  echo "Failed to copy heap profile from pod (base64)" >&2
  exit 1
fi

rm -f "$OUT"
strip_pilot_agent_newline "$TMP_RAW" "$OUT"

validate_profile

echo "Wrote: $OUT ($(wc -c <"$OUT" | tr -d ' ') bytes, $(file -b "$OUT" 2>/dev/null || echo 'binary'))" >&2
if [[ "$KEEP_REMOTE" == "1" ]]; then
  echo "Left remote file: $REMOTE_HEAP" >&2
fi

print_view_instructions
