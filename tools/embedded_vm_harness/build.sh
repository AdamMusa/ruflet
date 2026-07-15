#!/bin/sh
# Builds the desktop embedded-VM harness against the packaged macOS VM archive,
# exercising the same prebuilt runtime that applications receive.
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MRUBY="$ROOT/ruby_runtime/third_party/mruby"
VM_LIBRARY="$ROOT/ruby_runtime/macos/Frameworks/libruflet_vm.a"
OUT_DIR="$ROOT/tools/embedded_vm_harness/build"
mkdir -p "$OUT_DIR"

SDKROOT="${SDKROOT:-$(xcrun --show-sdk-path 2>/dev/null || true)}"
if [ -n "$SDKROOT" ]; then
  SYSROOT_FLAG="-isysroot $SDKROOT"
else
  SYSROOT_FLAG=""
fi

cc -O1 $SYSROOT_FLAG \
  -I"$MRUBY/include" \
  -I"$MRUBY/build/desktop_macos_arm64/include" \
  "$ROOT/tools/embedded_vm_harness/main.c" \
  "$VM_LIBRARY" \
  -lm \
  -o "$OUT_DIR/embedded_mruby"

echo "Built $OUT_DIR/embedded_mruby"
