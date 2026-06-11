#!/bin/sh
# Builds the desktop embedded-VM harness from the same vendored mruby sources
# the macOS plugin compiles (ruby_runtime/macos/ruby_runtime.podspec).
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/ruby_runtime/macos/mruby_src"
SHARED="$ROOT/ruby_runtime/shared"
OUT_DIR="$ROOT/tools/embedded_vm_harness/build"
mkdir -p "$OUT_DIR"

SDKROOT="${SDKROOT:-$(xcrun --show-sdk-path 2>/dev/null || true)}"
if [ -n "$SDKROOT" ]; then
  SYSROOT_FLAG="-isysroot $SDKROOT"
else
  SYSROOT_FLAG=""
fi

cc -O1 -DMRB_NO_PRESYM=1 $SYSROOT_FLAG \
  -I"$SRC/include" \
  -I"$SRC/src" \
  -I"$SRC/mrbgems/mruby-compiler/core" \
  -I"$SRC/mrbgems/mruby-io/include" \
  -I"$SRC/mrbgems/mruby-socket/include" \
  -I"$SRC/mrbgems/mruby-time/include" \
  -I"$SRC/mrbgems/mruby-dir/include" \
  "$SRC"/src/*.c \
  "$SRC/mrbgems/mruby-compiler/core/codegen.c" \
  "$SRC/mrbgems/mruby-compiler/core/y.tab.c" \
  "$SRC/mrbgems/mruby-error/src/exception.c" \
  "$SRC/mrbgems/mruby-errno/src/errno.c" \
  "$SRC/mrbgems/mruby-io/src/io.c" \
  "$SRC/mrbgems/mruby-io/src/file.c" \
  "$SRC/mrbgems/mruby-io/src/file_test.c" \
  "$SRC/mrbgems/mruby-io/src/mruby_io_gem.c" \
  "$SRC/mrbgems/mruby-socket/src/socket.c" \
  "$SRC/mrbgems/mruby-pack/src/pack.c" \
  "$SRC/mrbgems/mruby-metaprog/src/metaprog.c" \
  "$SRC/mrbgems/mruby-sprintf/src/sprintf.c" \
  "$SRC/mrbgems/hal-posix-io/src/io_hal.c" \
  "$SRC/mrbgems/hal-posix-socket/src/socket_hal.c" \
  "$SRC/mrbgems/hal-posix-dir/src/dir_hal.c" \
  "$SRC/mrbgems/mruby-fiber/src/fiber.c" \
  "$SRC/mrbgems/mruby-time/src/time.c" \
  "$SRC/mrbgems/mruby-math/src/math.c" \
  "$SRC/mrbgems/mruby-random/src/random.c" \
  "$SRC/mrbgems/mruby-binding/src/binding.c" \
  "$SRC/mrbgems/mruby-eval/src/eval.c" \
  "$SRC/mrbgems/mruby-data/src/data.c" \
  "$SRC/mrbgems/mruby-kernel-ext/src/kernel.c" \
  "$SRC/mrbgems/mruby-class-ext/src/class.c" \
  "$SRC/mrbgems/mruby-array-ext/src/array.c" \
  "$SRC/mrbgems/mruby-string-ext/src/string.c" \
  "$SRC/mrbgems/mruby-hash-ext/src/hash_ext.c" \
  "$SRC/mrbgems/mruby-numeric-ext/src/numeric_ext.c" \
  "$SRC/mrbgems/mruby-object-ext/src/object.c" \
  "$SRC/mrbgems/mruby-range-ext/src/range.c" \
  "$SRC/mrbgems/mruby-symbol-ext/src/symbol.c" \
  "$SRC/mrbgems/mruby-proc-ext/src/proc.c" \
  "$SRC/mrbgems/mruby-struct/src/struct.c" \
  "$SRC/mrbgems/mruby-set/src/set.c" \
  "$SRC/mrbgems/mruby-catch/src/catch.c" \
  "$SRC/mrbgems/mruby-method/src/method.c" \
  "$SRC/mrbgems/mruby-dir/src/dir.c" \
  "$SRC/build_host/mrblib/mrblib.c" \
  "$SRC/build_host/mrbgems/mruby-errno/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-io/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-socket/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-compar-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-enum-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-array-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-string-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-hash-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-numeric-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-object-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-range-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-symbol-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-proc-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-toplevel-ext/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-enumerator/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-enum-chain/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-enum-lazy/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-struct/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-set/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-catch/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-method/gem_init.c" \
  "$SRC/build_host/mrbgems/mruby-dir/gem_init.c" \
  "$SHARED/mruby_gems_init.c" \
  "$SHARED/mruby_digest_gem.c" \
  "$ROOT/tools/embedded_vm_harness/main.c" \
  -lm \
  -o "$OUT_DIR/embedded_mruby"

echo "Built $OUT_DIR/embedded_mruby"
