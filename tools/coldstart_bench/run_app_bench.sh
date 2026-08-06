#!/bin/sh
# Runs the Flutter cold-start harness N times and summarizes each stage.
#
# The harness prints one COLDBENCH line per run, with every stage timestamped
# against the plugin's +load (which happens before the Flutter engine exists).
#
# Usage: run_app_bench.sh <path/to/coldbench binary> [iterations] [label]
set -eu

APP="$1"
ITERATIONS="${2:-10}"
LABEL="${3:-run}"
RAW="$(mktemp -t ruflet_app_bench)"
trap 'rm -f "$RAW"' EXIT

i=0
while [ "$i" -lt "$ITERATIONS" ]; do
  i=$((i + 1))
  # A fresh process each time; the harness exits once it has its numbers.
  timeout 60 "$APP" 2>/dev/null | grep '^COLDBENCH ' >>"$RAW" || true
done

summarize() {
  sed -n "s/.*[^a-z_]$1=\([0-9.]*\).*/\1/p" "$RAW" | sort -n | awk -v label="$1" '
    { v[n++] = $1 }
    END {
      if (n == 0) { printf "  %-18s (no samples)\n", label; exit }
      printf "  %-18s min %7.1f   median %7.1f   max %7.1f ms\n",
             label, v[0], v[int(n / 2)], v[n - 1]
    }'
}

echo "== $LABEL: $(wc -l <"$RAW" | tr -d ' ') runs"
for stage in binding_ready assets_extracted start_called start_returned port_bound; do
  summarize "$stage"
done
