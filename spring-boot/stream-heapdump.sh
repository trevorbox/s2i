#!/usr/bin/env bash
# Stream a HotSpot heap dump from an OpenShift/Kubernetes pod to a local file
# without storing a full .hprof on the container overlay (FIFO on tmpfs + oc exec).
#
# Requires: oc, kubectl; optional: python3 (ephemeral exit verification).
# Run: ./stream-heapdump.sh --help

set -euo pipefail

usage() {
  local prog
  prog="$(basename "$0")"
  cat <<USAGE >&2
Stream a HotSpot heap dump from a pod to a local .hprof (FIFO on tmpfs + oc exec + kubectl debug).

Usage:
  $prog [--help] [OUTPUT_FILE]

Arguments:
  OUTPUT_FILE    Where to write the heap dump locally (default: ./heap.hprof)

Options:
  -h, --help     Show this message and exit.

Environment:
  NS                 Namespace (default: spring-boot-demo2)
  POD                Pod name (required unless POD_AUTO=1)
  POD_AUTO=1         Use first Running pod in NS (order not guaranteed if many)
  APP_C              Application container name (default: spring-boot-demo)
  JDK_IMAGE          Ephemeral image with jcmd (default: registry.access.redhat.com/ubi9/openjdk-21:latest)
  JVM_UID            runAsUser for ephemeral jcmd; default: UID of PID 1 in APP_C
  VERIFY_POLL_MAX    Max seconds to wait for ephemeral Terminated (default: 20)

Examples:
  NS=spring-boot-demo POD_AUTO=1 $prog ./heap.hprof
  NS=spring-boot-demo POD=my-pod-xxx $prog
  $prog --help
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

OUT="${1:-./heap.hprof}"
if [[ $# -gt 1 ]]; then
  echo "Too many arguments (expected at most one output path)." >&2
  usage
  exit 2
fi

NS="${NS:-spring-boot-demo2}"
APP_C="${APP_C:-spring-boot-demo}"
JDK_IMAGE="${JDK_IMAGE:-registry.access.redhat.com/ubi9/openjdk-21:latest}"
POD_AUTO="${POD_AUTO:-0}"
VERIFY_POLL_MAX="${VERIFY_POLL_MAX:-20}"
OUT="${1:-./heap.hprof}"

# Poll pod status until ephemeral container $3 shows terminated, or timeout.
# Prints one line to stdout: terminated|exitCode|reason|finishedAt | running| | | | waiting| |reason | absent
wait_for_ephemeral_terminated() {
  local ns=$1 pod=$2 ecname=$3
  local attempt=0 line phase
  if ! command -v python3 >/dev/null 2>&1; then
    echo "verify: python3 not found; skipping ephemeral exit check." >&2
    return 2
  fi
  while (( attempt < VERIFY_POLL_MAX )); do
    line="$(
      oc get pod -n "$ns" "$pod" -o json | EPHEMERAL_NAME="$ecname" python3 -c "
import json, os, sys
name = os.environ['EPHEMERAL_NAME']
pod = json.load(sys.stdin)
for s in pod.get('status', {}).get('ephemeralContainerStatuses') or []:
    if s.get('name') != name:
        continue
    st = s.get('state') or {}
    if 'terminated' in st:
        t = st['terminated']
        ec = t.get('exitCode')
        r = t.get('reason') or ''
        fa = t.get('finishedAt') or ''
        print(f'terminated|{ec}|{r}|{fa}')
        sys.exit(0)
    if 'running' in st:
        print('running|||')
        sys.exit(0)
    if 'waiting' in st:
        w = st.get('waiting') or {}
        print('waiting||' + str(w.get('reason', '')) + '|')
        sys.exit(0)
    print('other|||')
    sys.exit(0)
print('absent|||')
"
    )"
    phase="${line%%|*}"
    if [[ "$phase" == "terminated" ]]; then
      echo "$line"
      return 0
    fi
    sleep 1
    ((attempt += 1)) || true
  done
  echo "timeout|||"
  return 1
}

print_ephemeral_impact_note() {
  local ns=$1 pod=$2
  local ec_count="?"
  if command -v python3 >/dev/null 2>&1; then
    ec_count="$(
      oc get pod -n "$ns" "$pod" -o json | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("spec",{}).get("ephemeralContainers") or []))'
    )"
  fi
  cat >&2 <<EOF

--- Ephemeral debug container (impact) ---
- After exit: no ongoing CPU/memory from this debug container.
- Kubernetes keeps each ephemeral container in pod spec/status until the **pod is recreated**
  (rollout, delete pod, new revision). This run added one spec entry; this pod now lists ${ec_count} ephemeral container(s) total.
- If you hit the cluster limit on ephemeral containers per pod, recycle the pod before the next dump.
- This script does not change your app image; it only attaches tooling briefly.
EOF
}

if [[ -z "${POD:-}" ]]; then
  if [[ "$POD_AUTO" == "1" ]]; then
    POD="$(oc get pods -n "$NS" -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' | head -1)"
    if [[ -z "$POD" ]]; then
      echo "POD_AUTO=1 but no Running pod found in namespace $NS" >&2
      exit 1
    fi
    echo "Using pod: $POD" >&2
  else
    echo "Set POD to the target pod name, or POD_AUTO=1. Example:" >&2
    echo "  POD=\$(oc get pods -n $NS -o jsonpath='{.items[0].metadata.name}') $0 $OUT" >&2
    echo "Run: $(basename "$0") --help" >&2
    exit 1
  fi
fi

if [[ -z "${JVM_UID:-}" ]]; then
  JVM_UID="$(oc exec -n "$NS" "$POD" -c "$APP_C" -- stat -c '%u' /proc/1)"
fi

CUSTOM="$(mktemp)"
trap 'rm -f "$CUSTOM"' EXIT
{
  echo 'securityContext:'
  echo "  runAsUser: $JVM_UID"
  echo '  runAsGroup: 0'
} >"$CUSTOM"

PIPE="/dev/shm/heap-stream.$$"
EPHEMERAL="heapdump-pipe-$$"

rm -f "$OUT"

if ! oc exec -n "$NS" "$POD" -c "$APP_C" -- sh -c 'test -d /dev/shm'; then
  echo "App container has no /dev/shm; use a tmpfs-backed path or a shared memory volume." >&2
  exit 1
fi

oc exec -n "$NS" "$POD" -c "$APP_C" -- sh -c "rm -f '$PIPE' 2>/dev/null || true; mkfifo '$PIPE'; cat '$PIPE'" >"$OUT" &
READER_PID=$!
sleep 2

set +e
kubectl debug -n "$NS" "pod/$POD" \
  --image="$JDK_IMAGE" \
  --target="$APP_C" \
  -c "$EPHEMERAL" \
  --profile=legacy \
  --custom="$CUSTOM" \
  --attach=true \
  -- bash -lc 'JCMD=$(find /usr/lib/jvm -type f -name jcmd 2>/dev/null | head -1); exec "$JCMD" 1 GC.heap_dump -overwrite '"$PIPE"''
KUBECTL_DEBUG_RC=$?
set -e

if [[ "$KUBECTL_DEBUG_RC" -ne 0 ]]; then
  echo "kubectl debug failed (exit $KUBECTL_DEBUG_RC). Stopping FIFO reader..." >&2
  kill "$READER_PID" 2>/dev/null || true
  wait "$READER_PID" 2>/dev/null || true
  oc exec -n "$NS" "$POD" -c "$APP_C" -- rm -f "$PIPE" 2>/dev/null || true
  exit "$KUBECTL_DEBUG_RC"
fi

wait "$READER_PID" || true
oc exec -n "$NS" "$POD" -c "$APP_C" -- rm -f "$PIPE" 2>/dev/null || true

# Verify ephemeral container reached Terminated and explain impact
VERIFY_LINE=""
VERIFY_RC=0
VERIFY_LINE="$(wait_for_ephemeral_terminated "$NS" "$POD" "$EPHEMERAL")" || VERIFY_RC=$?
if [[ "$VERIFY_RC" -eq 0 ]]; then
  IFS='|' read -r _v_phase _v_exit _v_reason _v_finished <<<"$VERIFY_LINE"
  echo "verify: ephemeral container \"$EPHEMERAL\" -> Terminated (exit ${_v_exit:-?}, reason=${_v_reason:-?}, finishedAt=${_v_finished:-?})" >&2
elif [[ "$VERIFY_RC" -eq 2 ]]; then
  echo "verify: skipped (python3 not installed)" >&2
else
  _v_phase="${VERIFY_LINE%%|*}"
  echo "verify: ephemeral container \"$EPHEMERAL\" not confirmed Terminated within ${VERIFY_POLL_MAX}s (last phase=${_v_phase:-unknown}). Check: oc get pod -n \"$NS\" \"$POD\" -o yaml" >&2
fi
print_ephemeral_impact_note "$NS" "$POD"

echo "Wrote: $OUT ($(ls -lh "$OUT" | awk '{print $5}'))" >&2
file "$OUT" >&2 || true
