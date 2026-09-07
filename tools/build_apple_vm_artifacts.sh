#!/bin/sh
# Rebuilds the packaged Apple VM from the current committed Ruflet sources.
#
# The runtime is a static mruby archive plus two native objects:
#   - ruflet_vm_host.cpp owns the embedded mruby lifecycle.
#   - ruflet_in_process_bridge.cpp owns the renderer/Ruby byte queues.
#
# Builds are written under build/vm/artifacts unless --output is provided.
# Nothing in ruby_runtime/Frameworks is replaced unless --install is explicit.
#
#   sh tools/build_apple_vm_artifacts.sh macos
#   sh tools/build_apple_vm_artifacts.sh ios --output /tmp/ruflet-vm
#   sh tools/build_apple_vm_artifacts.sh apple --install
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/ruby_runtime"
MRUBY="${RUFLET_MRUBY:-$RUNTIME/third_party/mruby}"
TARGET="${1:-}"
OUTPUT="$ROOT/build/vm/artifacts"
INSTALL=0

[ -n "$TARGET" ] && shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { echo "--output requires a directory" >&2; exit 2; }
      OUTPUT="$2"
      shift 2
      ;;
    --install)
      INSTALL=1
      shift
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
done

case "$TARGET" in
  macos|ios|apple) ;;
  *) echo "usage: $0 {macos|ios|apple} [--output DIR] [--install]" >&2; exit 2 ;;
esac

[ -d "$MRUBY/src" ] || {
  echo "mruby is not populated; set RUFLET_MRUBY to a populated checkout" >&2
  exit 2
}

WORK="$ROOT/build/vm/apple"
mkdir -p "$WORK" "$OUTPUT"

compile_runtime_objects() {
  sdk="$1"
  arch="$2"
  minimum_flag="$3"
  include_dir="$4"
  prefix="$5"

  compiler="c++"
  sdk_flags=""
  if [ -n "$sdk" ]; then
    compiler="xcrun --sdk $sdk clang++"
  else
    sdkroot="$(xcrun --sdk macosx --show-sdk-path)"
    sdk_flags="-isysroot $sdkroot"
  fi

  # Word splitting is intentional for the compiler and platform flags.
  # shellcheck disable=SC2086
  $compiler -O2 -c -std=c++17 -arch "$arch" $minimum_flag -fPIC $sdk_flags \
    -I"$MRUBY/include" -I"$include_dir" \
    -I"$RUNTIME/desktop" -I"$RUNTIME/shared" \
    "$RUNTIME/desktop/ruflet_vm_host.cpp" -o "$WORK/$prefix-host.o"
  # shellcheck disable=SC2086
  $compiler -O2 -c -std=c++17 -arch "$arch" $minimum_flag -fPIC $sdk_flags \
    -I"$RUNTIME/desktop" \
    "$RUNTIME/desktop/ruflet_in_process_bridge.cpp" -o "$WORK/$prefix-bridge.o"
}

assemble_archive() {
  mruby_archive="$1"
  prefix="$2"
  destination="$3"
  /usr/bin/libtool -static -o "$destination" \
    "$mruby_archive" "$WORK/$prefix-host.o" "$WORK/$prefix-bridge.o" 2>/dev/null
}

verify_archive() {
  archive="$1"
  for symbol in \
    _ruflet_vm_start \
    _ruflet_bridge_send_to_ruby \
    _ruflet_bridge_try_receive_for_ruby \
    _ruflet_bridge_receive_for_renderer \
    _ruflet_bridge_close; do
    nm -gU "$archive" | grep -q " $symbol$" || {
      echo "$archive is missing $symbol" >&2
      exit 1
    }
  done
}

build_macos() {
  mkdir -p "$OUTPUT/macos"
  for arch in arm64 x86_64; do
    name="desktop_macos_$arch"
    echo "==> macOS $arch"
    rm -rf "$MRUBY/build/$name"
    (cd "$MRUBY" && RUFLET_VM_ARCH="$arch" \
      MRUBY_CONFIG="$RUNTIME/vm/build_config/desktop_macos.rb" ./minirake >/dev/null)
    compile_runtime_objects "" "$arch" "-mmacosx-version-min=10.15" \
      "$MRUBY/build/$name/include" "macos-$arch"
    assemble_archive "$MRUBY/build/$name/lib/libmruby.a" "macos-$arch" \
      "$WORK/libruflet_vm_macos_$arch.a"
  done

  artifact="$OUTPUT/macos/libruflet_vm.a"
  lipo -create "$WORK/libruflet_vm_macos_arm64.a" \
    "$WORK/libruflet_vm_macos_x86_64.a" -output "$artifact"
  strip -S "$artifact"
  verify_archive "$artifact"

  if [ "$INSTALL" -eq 1 ]; then
    cp "$artifact" "$RUNTIME/macos/Frameworks/libruflet_vm.a"
  fi
  shasum -a 256 "$artifact"
}

build_ios() {
  mkdir -p "$OUTPUT/ios/ios-arm64" "$OUTPUT/ios/ios-arm64_x86_64-simulator"

  echo "==> host mrbc"
  rm -rf "$MRUBY/build/host_mrbc"
  (cd "$MRUBY" && \
    MRUBY_CONFIG="$RUNTIME/vm/build_config/host_mrbc.rb" ./minirake >/dev/null)
  mrbc="$MRUBY/build/host_mrbc/bin/mrbc"

  for spec in \
    "iphoneos:arm64:ios_device_arm64" \
    "iphonesimulator:arm64:ios_sim_arm64" \
    "iphonesimulator:x86_64:ios_sim_x86_64"; do
    sdk="${spec%%:*}"
    rest="${spec#*:}"
    arch="${rest%%:*}"
    name="${rest#*:}"
    minimum_flag="-miphoneos-version-min=13.0"
    [ "$sdk" = "iphonesimulator" ] && minimum_flag="-mios-simulator-version-min=13.0"

    echo "==> iOS $sdk $arch"
    rm -rf "$MRUBY/build/$name"
    (cd "$MRUBY" && RUFLET_IOS_SDK="$sdk" RUFLET_IOS_ARCH="$arch" \
      RUFLET_VM_BUILD="$name" RUFLET_MRBC="$mrbc" \
      MRUBY_CONFIG="$RUNTIME/vm/build_config/ios.rb" ./minirake >/dev/null)
    compile_runtime_objects "$sdk" "$arch" "$minimum_flag" \
      "$MRUBY/build/$name/include" "$name"
    assemble_archive "$MRUBY/build/$name/lib/libmruby.a" "$name" \
      "$WORK/libruflet_vm_$name.a"
  done

  device="$OUTPUT/ios/ios-arm64/libruflet_vm.a"
  simulator="$OUTPUT/ios/ios-arm64_x86_64-simulator/libruflet_vm.a"
  cp "$WORK/libruflet_vm_ios_device_arm64.a" "$device"
  lipo -create "$WORK/libruflet_vm_ios_sim_arm64.a" \
    "$WORK/libruflet_vm_ios_sim_x86_64.a" -output "$simulator"
  strip -S "$device" "$simulator"
  verify_archive "$device"
  verify_archive "$simulator"

  if [ "$INSTALL" -eq 1 ]; then
    xcframework="$RUNTIME/ios/Frameworks/RufletVM.xcframework"
    cp "$device" "$xcframework/ios-arm64/libruflet_vm.a"
    cp "$simulator" \
      "$xcframework/ios-arm64_x86_64-simulator/libruflet_vm.a"
  fi
  shasum -a 256 "$device" "$simulator"
}

case "$TARGET" in
  macos) build_macos ;;
  ios) build_ios ;;
  apple) build_macos; build_ios ;;
esac
