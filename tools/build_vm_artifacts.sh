#!/bin/sh
# Rebuilds the packaged VM artifacts from current framework sources.
#
# Each platform's artifact is the mruby build for that target plus, on the
# platforms that link it statically, the VM host layer from desktop/. Android
# instead compiles everything through its own CMakeLists against the generated
# sources in build/host_vm, which is why it needs that build first.
#
# The gem sets differ by platform on purpose: Android ships ruflet-record
# (SQLite), Apple and desktop do not. Each build config already reflects that.
#
#   sh tools/build_vm_artifacts.sh android          # 4 ABIs
#   sh tools/build_vm_artifacts.sh macos            # arm64 + x86_64 universal
#   sh tools/build_vm_artifacts.sh ios              # device + simulator slices
#
# Needs ruby_runtime/third_party populated; run from a checkout that has it.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/ruby_runtime"
TARGET="${1:-}"

# third_party is not in version control, so a worktree does not have it.
# RUFLET_MRUBY points the build at a populated one; the framework sources still
# come from this checkout, because the build configs resolve their gem paths
# relative to themselves.
MRUBY="${RUFLET_MRUBY:-$RUNTIME/third_party/mruby}"
# The Android CMakeLists reaches third_party through a relative path, so it has
# to run from a tree that has it. Its own sources are not what changes here.
ANDROID_CPP="${RUFLET_ANDROID_CPP:-$RUNTIME/android/src/main/cpp}"

[ -d "$MRUBY/src" ] || { echo "third_party/mruby is empty; populate it first" >&2; exit 2; }

sha_of() { shasum -a 256 "$1" | cut -d' ' -f1; }

build_host_vm() {
  echo "==> host_vm (generated sources for the Android build)"
  config="${RUFLET_HOST_VM_CONFIG:-$RUNTIME/vm/build_config/host_vm.rb}"
  # From scratch, not incremental. Dropping a gem leaves its generated
  # gem_init.c behind, and the Android CMakeLists globs that directory: the
  # stale file still compiles against presyms the regenerated table no longer
  # defines, so the build fails on an undeclared MRB_IVSYM__*.
  rm -rf "$MRUBY/build/host_vm"
  (cd "$MRUBY" && MRUBY_CONFIG="$config" ./minirake >/dev/null)
}

build_android() {
  build_host_vm

  NDK="${ANDROID_NDK_HOME:-$HOME/Library/Android/sdk/ndk/27.0.12077973}"
  CMAKE="${RUFLET_CMAKE:-$HOME/Library/Android/sdk/cmake/3.31.6/bin/cmake}"
  NINJA="${RUFLET_NINJA:-$HOME/Library/Android/sdk/cmake/3.31.6/bin/ninja}"
  STRIP="$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip"
  SRC="$ANDROID_CPP"
  OUT="$RUNTIME/android/src/main/jniLibs"
  WORK="$ROOT/build/vm/android"

  for abi in arm64-v8a armeabi-v7a x86 x86_64; do
    echo "==> android $abi"
    # Configure from scratch every time: the CMakeLists globs the generated
    # gem_init files, and a stale cache silently keeps a stale file list.
    rm -rf "$WORK/$abi"
    "$CMAKE" -S "$SRC" -B "$WORK/$abi" \
      -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI="$abi" -DANDROID_PLATFORM=android-24 \
      -DCMAKE_BUILD_TYPE=Release -GNinja -DCMAKE_MAKE_PROGRAM="$NINJA" >/dev/null
    "$CMAKE" --build "$WORK/$abi" -j 8 >/dev/null
    mkdir -p "$OUT/$abi"
    cp "$WORK/$abi/libruby_runtime.so" "$OUT/$abi/libruby_runtime.so"
    # Debug sections are ~12MB per ABI and ship in every APK.
    "$STRIP" --strip-unneeded "$OUT/$abi/libruby_runtime.so"
    echo "    $(sha_of "$OUT/$abi/libruby_runtime.so")  $abi"
  done
}

build_macos() {
  WORK="$ROOT/build/vm/macos"
  mkdir -p "$WORK"
  SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

  for arch in arm64 x86_64; do
    echo "==> macos $arch"
    (cd "$MRUBY" && RUFLET_VM_ARCH="$arch" \
      MRUBY_CONFIG="$RUNTIME/vm/build_config/desktop_macos.rb" ./minirake >/dev/null)
    # std::filesystem in the host layer needs 10.15; the archive itself still
    # targets 10.14 for everything that does not use it.
    cc -O2 -c -std=c++17 -arch "$arch" -mmacosx-version-min=10.15 \
      -isysroot "$SDKROOT" \
      -I"$MRUBY/include" -I"$MRUBY/build/desktop_macos_$arch/include" \
      -I"$RUNTIME/shared" \
      "$RUNTIME/desktop/ruflet_vm_host.cpp" -o "$WORK/host_$arch.o"
    /usr/bin/libtool -static -o "$WORK/libruflet_vm_$arch.a" \
      "$MRUBY/build/desktop_macos_$arch/lib/libmruby.a" "$WORK/host_$arch.o" 2>/dev/null
  done

  lipo -create "$WORK/libruflet_vm_arm64.a" "$WORK/libruflet_vm_x86_64.a" \
    -output "$RUNTIME/macos/Frameworks/libruflet_vm.a"
  # Applications link this archive; they never debug mruby's C. The DWARF is
  # most of the file and nothing consumes it, so drop it and keep the symbol
  # table the linker needs.
  strip -S "$RUNTIME/macos/Frameworks/libruflet_vm.a"
  echo "    $(sha_of "$RUNTIME/macos/Frameworks/libruflet_vm.a")  libruflet_vm.a"
}

build_ios() {
  WORK="$ROOT/build/vm/ios"
  mkdir -p "$WORK"

  echo "==> host mrbc"
  (cd "$MRUBY" && MRUBY_CONFIG="$RUNTIME/vm/build_config/host_mrbc.rb" ./minirake >/dev/null)
  MRBC="$MRUBY/build/host_mrbc/bin/mrbc"

  # sdk:arch:build-name triples. The simulator gets both architectures so they
  # can be lipo'd into one slice, which is what the xcframework expects.
  for spec in "iphoneos:arm64:ios_device_arm64" \
              "iphonesimulator:arm64:ios_sim_arm64" \
              "iphonesimulator:x86_64:ios_sim_x86_64"; do
    sdk="${spec%%:*}"; rest="${spec#*:}"; arch="${rest%%:*}"; name="${rest#*:}"
    echo "==> ios $sdk $arch"
    (cd "$MRUBY" && RUFLET_IOS_SDK="$sdk" RUFLET_IOS_ARCH="$arch" \
      RUFLET_VM_BUILD="$name" RUFLET_MRBC="$MRBC" \
      MRUBY_CONFIG="$RUNTIME/vm/build_config/ios.rb" ./minirake >/dev/null)

    min_flag="-miphoneos-version-min=13.0"
    [ "$sdk" = "iphonesimulator" ] && min_flag="-mios-simulator-version-min=13.0"
    xcrun --sdk "$sdk" clang++ -O2 -c -std=c++17 -arch "$arch" $min_flag -fPIC \
      -I"$MRUBY/include" -I"$MRUBY/build/$name/include" -I"$RUNTIME/shared" \
      "$RUNTIME/desktop/ruflet_vm_host.cpp" -o "$WORK/host_$name.o"
    /usr/bin/libtool -static -o "$WORK/libruflet_vm_$name.a" \
      "$MRUBY/build/$name/lib/libmruby.a" "$WORK/host_$name.o" 2>/dev/null
  done

  lipo -create "$WORK/libruflet_vm_ios_sim_arm64.a" "$WORK/libruflet_vm_ios_sim_x86_64.a" \
    -output "$WORK/libruflet_vm_simulator.a"

  XC="$RUNTIME/ios/Frameworks/RufletVM.xcframework"
  cp "$WORK/libruflet_vm_ios_device_arm64.a" "$XC/ios-arm64/libruflet_vm.a"
  cp "$WORK/libruflet_vm_simulator.a" "$XC/ios-arm64_x86_64-simulator/libruflet_vm.a"
  # See the note in build_macos: the DWARF is dead weight for consumers.
  strip -S "$XC/ios-arm64/libruflet_vm.a" "$XC/ios-arm64_x86_64-simulator/libruflet_vm.a"
  echo "    $(sha_of "$XC/ios-arm64/libruflet_vm.a")  ios-arm64"
  echo "    $(sha_of "$XC/ios-arm64_x86_64-simulator/libruflet_vm.a")  simulator"
}

case "$TARGET" in
  android) build_android ;;
  macos)   build_macos ;;
  ios)     build_ios ;;
  *) echo "usage: $0 {android|macos|ios}" >&2; exit 2 ;;
esac
