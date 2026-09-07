#!/bin/sh
# Links the host-level integration test against a packaged or freshly built
# macOS VM archive and proves a real Ruflet page crosses the in-process bridge.
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VM_LIBRARY="${RUFLET_VM_LIBRARY:-$ROOT/ruby_runtime/macos/Frameworks/libruflet_vm.a}"
OUT_DIR="$ROOT/build/embedded_vm_harness"
FIXTURE_ROOT="$ROOT/tools/embedded_vm_harness/tests/in_process_app"
APP_ROOT="$(mktemp -d /tmp/ruflet-in-process-app.XXXXXX)"
trap 'rm -rf "$APP_ROOT"' EXIT

[ -f "$VM_LIBRARY" ] || { echo "VM archive not found: $VM_LIBRARY" >&2; exit 2; }
mkdir -p "$OUT_DIR"
cp "$FIXTURE_ROOT/main.rb" "$APP_ROOT/main.rb"

c++ -O2 -std=c++17 \
  -I"$ROOT/ruby_runtime/desktop" \
  "$ROOT/tools/embedded_vm_harness/in_process_main.cpp" \
  "$VM_LIBRARY" -lm -o "$OUT_DIR/in_process_vm_test"

"$OUT_DIR/in_process_vm_test" "$APP_ROOT"
