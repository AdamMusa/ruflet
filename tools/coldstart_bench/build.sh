#!/bin/sh
# Builds the cold-start benchmark against the packaged macOS VM archive.
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VM_LIBRARY="$ROOT/ruby_runtime/macos/Frameworks/libruflet_vm.a"
OUT_DIR="$ROOT/tools/coldstart_bench/build"
mkdir -p "$OUT_DIR"

SDKROOT="${SDKROOT:-$(xcrun --show-sdk-path 2>/dev/null || true)}"
if [ -n "$SDKROOT" ]; then
  SYSROOT_FLAG="-isysroot $SDKROOT"
else
  SYSROOT_FLAG=""
fi

MRUBY="$ROOT/ruby_runtime/third_party/mruby"

cc -O2 $SYSROOT_FLAG \
  "$ROOT/tools/coldstart_bench/bench_vm.c" \
  "$VM_LIBRARY" \
  -lm -lc++ \
  -o "$OUT_DIR/bench_vm"

echo "Built $OUT_DIR/bench_vm"

# The phase probe reaches into mruby directly to time individual boot stages,
# so unlike bench_vm it needs the mruby headers the archive was built against.
cc -O2 $SYSROOT_FLAG \
  -I"$MRUBY/include" \
  -I"$MRUBY/build/desktop_macos_arm64/include" \
  "$ROOT/tools/coldstart_bench/bench_phases.c" \
  "$VM_LIBRARY" \
  -lm -lc++ \
  -o "$OUT_DIR/bench_phases"

echo "Built $OUT_DIR/bench_phases"
