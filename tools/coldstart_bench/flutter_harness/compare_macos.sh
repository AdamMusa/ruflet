#!/bin/sh
# Runs both startup designs N times and reports each stage on the platform
# timeline (which starts before the Flutter engine did).
#
#   extensions_ready  Dart main has initialized the Flet extensions
#   url_ready         the app knows where its embedded server is
#   flet_app_frame    the frame that mounts FletApp has been painted
#
# Usage: compare_macos.sh [iterations]
set -eu

SP=/private/tmp/claude-501/-Users-macbookpro-Documents-Izeesoft-FlutterApp-ruflet--claude-worktrees-ruflet-hotreload-brainstorm-a5add2/d400b500-ab53-4762-9133-a47c634f5104/scratchpad
ITER=${1:-8}

med() {
  sed -n "s/.*COLDBENCH_MARK $2=\([0-9.-]*\).*/\1/p" "$1" | sort -n |
    awk '{v[n++]=$1} END {if(n) printf "%7.1f", v[int(n/2)]; else printf "      -"}'
}

for variant in A_eager B_eager; do
  case $variant in
    A_eager) label="A: Dart-driven  + eager VM (SHIPS TODAY)" ;;
    B_eager) label="B: autostart    + eager VM             " ;;
  esac
  RAW=$SP/compare_$variant.txt
  : > "$RAW"

  # One warmup run, discarded: a freshly written binary pays first-launch costs.
  timeout 60 "$SP/$variant.app/Contents/MacOS/Physic" >/dev/null 2>&1 &
  sleep 8; pkill -f "$SP/$variant.app" 2>/dev/null || true; sleep 1

  i=0
  while [ "$i" -lt "$ITER" ]; do
    i=$((i + 1))
    timeout 60 "$SP/$variant.app/Contents/MacOS/Physic" >>"$RAW" 2>&1 &
    PID=$!
    sleep 8
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
  done

  printf "%s extensions_ready %s   url_ready %s   flet_app_frame %s ms\n" \
    "$label" \
    "$(med "$RAW" extensions_ready)" \
    "$(med "$RAW" url_ready)" \
    "$(med "$RAW" flet_app_frame)"
done
