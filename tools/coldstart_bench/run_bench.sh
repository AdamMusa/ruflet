#!/bin/sh
# Runs the VM cold-start benchmark N times in fresh processes and reports the
# distribution. A fresh process per iteration matters: the VM host keeps
# process-global state and boots once, so repeated in-process runs would measure
# a warm VM.
#
# Usage: run_bench.sh <project_root> <entrypoint> [iterations]
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BENCH="$ROOT/tools/coldstart_bench/build/bench_vm"
PROJECT="$1"
ENTRYPOINT="$2"
ITERATIONS="${3:-10}"
RAW="$(mktemp -t ruflet_bench)"
trap 'rm -f "$RAW"' EXIT

[ -x "$BENCH" ] || { echo "build it first: sh tools/coldstart_bench/build.sh" >&2; exit 2; }

i=0
while [ "$i" -lt "$ITERATIONS" ]; do
  i=$((i + 1))
  if ! "$BENCH" "$PROJECT" "$ENTRYPOINT" >>"$RAW" 2>/dev/null; then
    echo "iteration $i failed" >&2
  fi
done

summarize() {
  field="$1"
  label="$2"
  sed -n "s/.*${field}=\([0-9.]*\).*/\1/p" "$RAW" | sort -n | awk -v label="$label" '
    { v[n++] = $1 }
    END {
      if (n == 0) exit
      printf "  %-26s min %7.1f   median %7.1f   p90 %7.1f   max %7.1f ms\n",
             label, v[0], v[int(n / 2)], v[int(n * 0.9)], v[n - 1]
    }'
}

echo "iterations: $(wc -l <"$RAW" | tr -d ' ')  project: $PROJECT"
summarize start_returns_ms "ruflet_vm_start() returns"
summarize port_bound_ms "start -> port bound"
