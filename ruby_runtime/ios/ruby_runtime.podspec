Pod::Spec.new do |s|
  s.name             = 'ruby_runtime'
  s.version          = '0.0.1'
  s.summary          = 'mruby runtime bridge for Flutter (Android/iOS).'
  s.description      = <<-DESC
Embeds mruby in native iOS code and exposes eval/runFile/reset over a Flutter method channel.
                       DESC
  s.homepage         = 'https://github.com/AdamMusa/ruflet'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Izeesoft' => 'dev@izeesoft.com' }
  s.source           = { :path => '.' }

  s.source_files = [
    'Classes/**/*.{h,m,mm,c,cc,cpp}',
    'Classes/mruby_digest_gem.c',
    'mruby_src/src/*.c',
    'mruby_src/mrbgems/mruby-compiler/core/codegen.c',
    'mruby_src/mrbgems/mruby-compiler/core/y.tab.c',
    'mruby_src/mrbgems/mruby-error/src/exception.c',
    'mruby_src/mrbgems/mruby-errno/src/errno.c',
    'mruby_src/mrbgems/mruby-io/src/io.c',
    'mruby_src/mrbgems/mruby-io/src/file.c',
    'mruby_src/mrbgems/mruby-io/src/file_test.c',
    'mruby_src/mrbgems/mruby-io/src/mruby_io_gem.c',
    'mruby_src/mrbgems/mruby-socket/src/socket.c',
    'mruby_src/mrbgems/mruby-pack/src/pack.c',
    'mruby_src/mrbgems/mruby-metaprog/src/metaprog.c',
    'mruby_src/mrbgems/mruby-sprintf/src/sprintf.c',
    'mruby_src/mrbgems/hal-posix-io/src/io_hal.c',
    'mruby_src/mrbgems/hal-posix-socket/src/socket_hal.c',
    'mruby_src/mrbgems/hal-posix-dir/src/dir_hal.c',
    'mruby_src/mrbgems/mruby-fiber/src/fiber.c',
    'mruby_src/mrbgems/mruby-time/src/time.c',
    'mruby_src/mrbgems/mruby-math/src/math.c',
    'mruby_src/mrbgems/mruby-random/src/random.c',
    'mruby_src/mrbgems/mruby-binding/src/binding.c',
    'mruby_src/mrbgems/mruby-eval/src/eval.c',
    'mruby_src/mrbgems/mruby-data/src/data.c',
    'mruby_src/mrbgems/mruby-kernel-ext/src/kernel.c',
    'mruby_src/mrbgems/mruby-class-ext/src/class.c',
    'mruby_src/mrbgems/mruby-array-ext/src/array.c',
    'mruby_src/mrbgems/mruby-string-ext/src/string.c',
    'mruby_src/mrbgems/mruby-hash-ext/src/hash_ext.c',
    'mruby_src/mrbgems/mruby-numeric-ext/src/numeric_ext.c',
    'mruby_src/mrbgems/mruby-object-ext/src/object.c',
    'mruby_src/mrbgems/mruby-range-ext/src/range.c',
    'mruby_src/mrbgems/mruby-symbol-ext/src/symbol.c',
    'mruby_src/mrbgems/mruby-proc-ext/src/proc.c',
    'mruby_src/mrbgems/mruby-struct/src/struct.c',
    'mruby_src/mrbgems/mruby-set/src/set.c',
    'mruby_src/mrbgems/mruby-catch/src/catch.c',
    'mruby_src/mrbgems/mruby-method/src/method.c',
    'mruby_src/mrbgems/mruby-dir/src/dir.c',
    'mruby_src/build_host/mrblib/mrblib.c',
    'mruby_src/build_host/mrbgems/mruby-errno/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-io/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-socket/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-compar-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-enum-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-array-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-string-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-hash-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-numeric-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-object-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-range-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-symbol-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-proc-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-toplevel-ext/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-enumerator/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-enum-chain/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-enum-lazy/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-struct/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-set/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-catch/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-method/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-dir/gem_init.c'
  ]

  s.public_header_files = 'Classes/**/*.h'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.libraries = 'm'

  # Vendored mruby C sources trip style lints (uninitialized-variable
  # false positives around MRB_ENSURE, 64->32 narrowing, comma operator).
  # They are upstream code; keep plugin build logs readable.
  s.compiler_flags = '-Wno-conditional-uninitialized -Wno-shorten-64-to-32 -Wno-comma'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Vendored mruby headers carry malformed Doxygen comments; the
    # documentation lint is upstream noise for this pod.
    'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/mruby_src/include" "$(PODS_TARGET_SRCROOT)/mruby_src/src" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-compiler/core" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-io/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-socket/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-time/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-dir/include"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MRB_NO_PRESYM=1'
  }
end
