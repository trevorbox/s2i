#!/usr/bin/env bash
# Dump an Envoy / istio-proxy heap profile via the admin API (GET /heap_dump).
#
# Calls Envoy GET /heap_dump on the admin port (default 15000) via pilot-agent,
# curl, or wget inside the proxy container, then copies the profile with base64.
# Some transports append a trailing newline — the script strips that for gzip/pprof.
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
  PROXY_C           Proxy container name (default: istio-proxy)
  PROXY_AUTO=1      Pick first running container/initContainer with admin access
  ADMIN_PORT        Envoy admin port (default: 15000)
  ADMIN_MODE        Force admin client: pilot-agent, curl, or wget
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
PROXY_AUTO="${PROXY_AUTO:-0}"
ADMIN_PORT="${ADMIN_PORT:-15000}"
ADMIN_MODE="${ADMIN_MODE:-}"
ADMIN_CMD=""
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
  case "$ADMIN_MODE" in
    pilot-agent)
      proxy_exec "$ADMIN_CMD" request "$method" "$path"
      ;;
    curl)
      proxy_exec curl -sf "http://127.0.0.1:${ADMIN_PORT}${path}"
      ;;
    wget)
      proxy_exec wget -qO- "http://127.0.0.1:${ADMIN_PORT}${path}"
      ;;
    *)
      echo "Internal error: unknown ADMIN_MODE=$ADMIN_MODE" >&2
      exit 1
      ;;
  esac
}

admin_fetch_to_file() {
  local path=$1 dest=$2
  case "$ADMIN_MODE" in
    pilot-agent)
      proxy_exec sh -c "'$ADMIN_CMD' request GET '$path' > '$dest' 2>/dev/null"
      ;;
    curl)
      proxy_exec sh -c "curl -sf 'http://127.0.0.1:${ADMIN_PORT}${path}' -o '$dest'"
      ;;
    wget)
      proxy_exec sh -c "wget -q -O '$dest' 'http://127.0.0.1:${ADMIN_PORT}${path}'"
      ;;
    *)
      echo "Internal error: unknown ADMIN_MODE=$ADMIN_MODE" >&2
      exit 1
      ;;
  esac
}

# shellcheck disable=SC2016
probe_admin_client() {
  proxy_exec sh -c '
    for pa in pilot-agent /usr/local/bin/pilot-agent /usr/bin/pilot-agent; do
      if command -v "$pa" >/dev/null 2>&1; then
        printf "pilot-agent %s\n" "$(command -v "$pa")"
        exit 0
      fi
    done
    command -v curl >/dev/null 2>&1 && { echo curl; exit 0; }
    command -v wget >/dev/null 2>&1 && { echo wget; exit 0; }
    exit 1
  ' 2>/dev/null
}

apply_admin_probe() {
  local probe=$1
  ADMIN_MODE="${probe%% *}"
  if [[ "$ADMIN_MODE" == "pilot-agent" ]]; then
    ADMIN_CMD="${probe#* }"
  else
    ADMIN_CMD=""
  fi
}

resolve_admin_access() {
  local probe
  if [[ -n "$ADMIN_MODE" ]]; then
    case "$ADMIN_MODE" in
      pilot-agent)
        ADMIN_CMD="${ADMIN_CMD:-$(probe_admin_client | awk '$1=="pilot-agent"{print $2; exit}')}"
        if [[ -z "$ADMIN_CMD" ]]; then
          for c in pilot-agent /usr/local/bin/pilot-agent /usr/bin/pilot-agent; do
            if proxy_exec sh -c "command -v '$c' >/dev/null 2>&1" 2>/dev/null; then
              ADMIN_CMD="$(proxy_exec sh -c "command -v '$c'" 2>/dev/null | tr -d '\r')"
              break
            fi
          done
        fi
        ;;
      curl | wget)
        ADMIN_CMD=""
        if ! proxy_exec command -v "$ADMIN_MODE" >/dev/null 2>&1; then
          return 1
        fi
        ;;
      *)
        echo "Invalid ADMIN_MODE=$ADMIN_MODE (use pilot-agent, curl, or wget)" >&2
        exit 1
        ;;
    esac
    if [[ "$ADMIN_MODE" == "pilot-agent" && -z "$ADMIN_CMD" ]]; then
      return 1
    fi
    return 0
  fi
  probe="$(probe_admin_client)" || return 1
  apply_admin_probe "$probe"
}

pod_running_inits() {
  oc get pod -n "$NS" "$POD" -o jsonpath='{range .status.initContainerStatuses[?(@.state.running)]}{.name}{" "}{end}' 2>/dev/null
}

proxy_is_running() {
  local containers=$1 running_inits=$2
  [[ " $containers " == *" $PROXY_C "* ]] && return 0
  [[ " $running_inits " == *" $PROXY_C "* ]] && return 0
  return 1
}

print_admin_diagnostic() {
  local containers=$1 init_containers=$2 running_inits=$3
  echo "Cannot reach Envoy admin API in $NS/$POD container \"$PROXY_C\"." >&2
  echo "  Need pilot-agent, curl, or wget plus Envoy on port ${ADMIN_PORT}." >&2
  echo "  Pod containers: ${containers:-none}" >&2
  echo "  Pod initContainers: ${init_containers:-none}" >&2
  echo "  Running initContainers: ${running_inits:-none}" >&2
  echo "  OSSM/Istio may inject istio-proxy as a native sidecar initContainer (not spec.containers)." >&2
  echo "  Completed inits (e.g. istio-validation) cannot be used — only running targets above." >&2
  echo "  Try: PROXY_AUTO=1 $0   or   PROXY_C=<running-proxy-name> $0" >&2
  echo "  Probe: oc exec -n $NS $POD -c $PROXY_C -- sh -c 'command -v pilot-agent curl wget; ss -tlnp 2>/dev/null | grep -E \"15000|15021\" || netstat -tlnp 2>/dev/null | grep 15000'" >&2
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
  local containers init_containers running_inits c probe_label want_proxy="${PROXY_C}"
  local proxy_kind="" auto_candidates=()
  if ! oc get pod -n "$NS" "$POD" >/dev/null 2>&1; then
    echo "Pod not found: $NS/$POD" >&2
    exit 1
  fi
  containers="$(oc get pod -n "$NS" "$POD" -o jsonpath='{.spec.containers[*].name}')"
  init_containers="$(oc get pod -n "$NS" "$POD" -o jsonpath='{.spec.initContainers[*].name}')"
  running_inits="$(pod_running_inits)"

  try_admin_for_container() {
    proxy_is_running "$containers" "$running_inits" || return 1
    resolve_admin_access
  }

  report_proxy_pick() {
    probe_label="$ADMIN_MODE"
    [[ -n "$ADMIN_CMD" ]] && probe_label="$ADMIN_MODE ($ADMIN_CMD)"
    if [[ " $running_inits " == *" $PROXY_C "* && " $containers " != *" $PROXY_C "* ]]; then
      proxy_kind="initContainer (native sidecar)"
    else
      proxy_kind="container"
    fi
    echo "Admin client: $probe_label on 127.0.0.1:${ADMIN_PORT} in $PROXY_C ($proxy_kind)" >&2
  }

  if try_admin_for_container; then
    report_proxy_pick
    return 0
  fi

  if [[ "$PROXY_AUTO" == "1" ]]; then
    # Prefer istio-proxy, then other running inits, then app containers.
    auto_candidates=()
    [[ " $running_inits " == *" istio-proxy "* ]] && auto_candidates+=(istio-proxy)
    for c in $running_inits; do
      [[ "$c" == "istio-proxy" ]] && continue
      auto_candidates+=("$c")
    done
    for c in $containers; do
      auto_candidates+=("$c")
    done
    for c in "${auto_candidates[@]}"; do
      PROXY_C="$c"
      if try_admin_for_container; then
        report_proxy_pick
        echo "PROXY_AUTO: selected $PROXY_C" >&2
        return 0
      fi
    done
  fi

  PROXY_C="$want_proxy"
  if [[ " $containers $init_containers " != *" $want_proxy "* ]]; then
    echo "Container \"$want_proxy\" not found on pod $POD" >&2
  elif [[ " $running_inits " != *" $want_proxy "* && " $containers " != *" $want_proxy "* ]]; then
    echo "Container \"$want_proxy\" exists but is not running (check pod status)" >&2
  fi
  print_admin_diagnostic "$containers" "$init_containers" "$running_inits"
  exit 1
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

last_byte_hex() {
  # Command substitution strips a trailing newline from $(tail -c 1), so compare hex instead.
  tail -c 1 "$1" | od -An -tx1 2>/dev/null | tr -d ' \n'
}

strip_transport_suffix() {
  # pilot-agent and oc exec base64 often append trailing CR/LF after binary data.
  local raw=$1 final=$2
  local sz stripped=0 last_hex
  sz=$(wc -c <"$raw" | tr -d ' ')
  if [[ "$sz" -eq 0 ]]; then
    echo "Downloaded heap profile is empty" >&2
    return 1
  fi
  while [[ "$sz" -gt 0 ]]; do
    last_hex=$(last_byte_hex "$raw")
    if [[ "$last_hex" == "0a" || "$last_hex" == "0d" ]]; then
      truncate -s $((sz - 1)) "$raw"
      stripped=$((stripped + 1))
      sz=$((sz - 1))
    else
      break
    fi
  done
  if [[ "$stripped" -gt 0 ]]; then
    echo "Stripped ${stripped} trailing newline byte(s) from download" >&2
  fi
  mv -f "$raw" "$final"
}

validate_profile() {
  if command -v gzip >/dev/null 2>&1; then
    if ! gzip -t "$OUT" 2>/dev/null; then
      local last_hex sz
      last_hex=$(last_byte_hex "$OUT")
      if [[ "$last_hex" == "0a" || "$last_hex" == "0d" ]]; then
        sz=$(wc -c <"$OUT" | tr -d ' ')
        truncate -s $((sz - 1)) "$OUT"
        echo "Stripped trailing newline from $OUT (bash transport quirk)" >&2
      fi
    fi
    if ! gzip -t "$OUT" 2>/dev/null; then
      echo "Warning: $OUT is not valid gzip (truncated dump, admin error body, or copy corruption?)" >&2
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
      $0 --memory   (or curl localhost:${ADMIN_PORT}/memory inside the proxy)
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
if ! admin_fetch_to_file /heap_dump "$REMOTE_HEAP"; then
  echo "GET /heap_dump failed ($ADMIN_MODE on 127.0.0.1:${ADMIN_PORT})" >&2
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
strip_transport_suffix "$TMP_RAW" "$OUT"

validate_profile

echo "Wrote: $OUT ($(wc -c <"$OUT" | tr -d ' ') bytes, $(file -b "$OUT" 2>/dev/null || echo 'binary'))" >&2
if [[ "$KEEP_REMOTE" == "1" ]]; then
  echo "Left remote file: $REMOTE_HEAP" >&2
fi

print_view_instructions
