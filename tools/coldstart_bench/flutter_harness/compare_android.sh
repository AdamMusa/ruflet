#!/bin/sh
# Runs both startup designs on a connected Android device N times and reports
# each stage on the platform timeline, which starts at the androidx.startup
# initializer -- before Application.onCreate and long before the engine.
#
# Each iteration force-stops and clears the app first, so every run pays a real
# cold start rather than reusing a warm process. Clearing also resets the
# unpacked project, so both designs unpack once per run and neither gets a free
# ride from the previous iteration.
set -eu

SP=/private/tmp/claude-501/-Users-macbookpro-Documents-Izeesoft-FlutterApp-ruflet--claude-worktrees-ruflet-hotreload-brainstorm-a5add2/d400b500-ab53-4762-9133-a47c634f5104/scratchpad
ADB=$HOME/Library/Android/sdk/platform-tools/adb
PKG=com.example.ruflet_client
ITER=${1:-6}

med() {
  sed -n "s/.*COLDBENCH_MARK $2=\([0-9.-]*\).*/\1/p" "$1" | sort -n |
    awk '{v[n++]=$1} END {if(n) printf "%7.1f", v[int(n/2)]; else printf "      -"}'
}

for variant in A B; do
  case $variant in
    A) label="A: Dart-driven (today)" ;;
    B) label="B: platform autostart " ;;
  esac

  "$ADB" uninstall "$PKG" >/dev/null 2>&1 || true
  "$ADB" install -r "$SP/android_$variant.apk" >/dev/null 2>&1

  RAW="$SP/compare_android_$variant.txt"
  : > "$RAW"

  i=0
  while [ "$i" -lt "$((ITER + 1))" ]; do
    i=$((i + 1))
    "$ADB" shell am force-stop "$PKG" >/dev/null 2>&1
    "$ADB" shell pm clear "$PKG" >/dev/null 2>&1
    "$ADB" logcat -c >/dev/null 2>&1
    "$ADB" shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1
    sleep 12
    # The first run after install is discarded: it pays dexopt and first-launch
    # costs that have nothing to do with either startup design.
    if [ "$i" -gt 1 ]; then
      "$ADB" logcat -d 2>/dev/null | grep 'COLDBENCH_MARK' >>"$RAW" || true
    fi
  done

  printf "%s  extensions_ready %s   url_ready %s   flet_app_frame %s ms\n" \
    "$label" \
    "$(med "$RAW" extensions_ready)" \
    "$(med "$RAW" url_ready)" \
    "$(med "$RAW" flet_app_frame)"
done
