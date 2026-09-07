#!/bin/sh
# Runs the real-app cold start across both startup designs and both VMs.
set -eu

SP=/private/tmp/claude-501/-Users-macbookpro-Documents-Izeesoft-FlutterApp-ruflet--claude-worktrees-ruflet-hotreload-brainstorm-a5add2/d400b500-ab53-4762-9133-a47c634f5104/scratchpad
W=/Users/macbookpro/Documents/Izeesoft/FlutterApp/ruflet/.claude/worktrees/ruflet-hotreload-brainstorm-a5add2
PATH=/Users/macbookpro/Documents/setup/flutter/bin:$PATH
export PATH
APP=$SP/coldbench/build/macos/Build/Products/Release/coldbench.app/Contents/MacOS/coldbench
ITER=${1:-8}

med() {
  sed -n "s/.*[^a-z_]$2=\([0-9.-]*\).*/\1/p" "$1" | sort -n |
    awk '{v[n++]=$1} END {if(n) printf "%7.1f", v[int(n/2)]; else printf "      -"}'
}

for vm in lazy eager; do
  case $vm in
    lazy)  cp $SP/libruflet_vm_fat_lazy.a $W/ruby_runtime/macos/Frameworks/libruflet_vm.a ;;
    eager) cp $SP/libruflet_vm_shipped_fat.a $W/ruby_runtime/macos/Frameworks/libruflet_vm.a ;;
  esac

  for mode in dart autostart; do
    case $mode in
      dart)      $SP/set_autostart.sh $SP/coldbench/macos/Runner/Info.plist false >/dev/null ;;
      autostart) $SP/set_autostart.sh $SP/coldbench/macos/Runner/Info.plist true  >/dev/null ;;
    esac

    (cd $SP/coldbench && rm -rf build/macos &&
      flutter build macos --release -t lib/main_real_app.dart \
        --dart-define=COLDBENCH_MODE=$mode 2>&1 | grep -E "error:" || true) >/dev/null

    RAW=$SP/matrix_${vm}_${mode}.txt
    : > "$RAW"
    i=0
    while [ "$i" -lt "$ITER" ]; do
      i=$((i + 1))
      timeout 90 "$APP" 2>/dev/null | grep -E '^COLDBENCH' >>"$RAW" || true
    done

    ok=$(grep -c '^COLDBENCH ' "$RAW" || true)
    bytes=$(sed -n 's/.*page_patch_bytes=\([0-9]*\).*/\1/p' "$RAW" | sort -n | tail -1)
    printf "%-6s %-10s  first_frame %s   server_bound %s   page_rendered %s   (ok %s/%s, patch %s B)\n" \
      "$vm" "$mode" \
      "$(med "$RAW" first_frame)" \
      "$(med "$RAW" server_bound)" \
      "$(med "$RAW" page_rendered)" \
      "$ok" "$ITER" "${bytes:-0}"
  done
done
