Pod::Spec.new do |s|
  s.name             = 'ruby_runtime'
  s.version          = '0.0.1'
  s.summary          = 'Embedded Ruby (mruby) VM for Flutter macOS.'
  s.description      = <<-DESC
Embeds a generic mruby VM with gem-loading support ($LOAD_PATH/require) and
exposes start/status/stop over a Flutter method channel. Application
frameworks ship as plain gem file trees in app assets.
                       DESC
  s.homepage         = 'https://github.com/AdamMusa/ruflet'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Izeesoft' => 'dev@izeesoft.com' }

  s.source = { :path => '.' }
  s.source_files = [
    'Classes/**/*.{h,m,mm,c,cc,cpp}',
    'mruby_src/src/*.c',
    'mruby_src/mrbgems/mruby-error/src/*.c',
    'mruby_src/mrbgems/mruby-bigint/core/*.c',
    'mruby_src/mrbgems/mruby-errno/src/*.c',
    'mruby_src/mrbgems/mruby-array-ext/src/*.c',
    'mruby_src/mrbgems/mruby-string-ext/src/*.c',
    'mruby_src/mrbgems/mruby-hash-ext/src/*.c',
    'mruby_src/mrbgems/mruby-object-ext/src/*.c',
    'mruby_src/mrbgems/mruby-kernel-ext/src/*.c',
    'mruby_src/mrbgems/mruby-symbol-ext/src/*.c',
    'mruby_src/mrbgems/mruby-proc-ext/src/*.c',
    'mruby_src/mrbgems/mruby-binding/src/*.c',
    'mruby_src/mrbgems/mruby-proc-binding/src/*.c',
    'mruby_src/mrbgems/mruby-eval/src/*.c',
    'mruby_src/mrbgems/mruby-class-ext/src/*.c',
    'mruby_src/mrbgems/mruby-compar-ext/src/*.c',
    'mruby_src/mrbgems/mruby-range-ext/src/*.c',
    'mruby_src/mrbgems/mruby-numeric-ext/src/*.c',
    'mruby_src/mrbgems/mruby-toplevel-ext/src/*.c',
    'mruby_src/mrbgems/mruby-metaprog/src/*.c',
    'mruby_src/mrbgems/mruby-method/src/*.c',
    'mruby_src/mrbgems/mruby-data/src/*.c',
    'mruby_src/mrbgems/mruby-struct/src/*.c',
    'mruby_src/mrbgems/mruby-set/src/*.c',
    'mruby_src/mrbgems/mruby-fiber/src/*.c',
    'mruby_src/mrbgems/mruby-enumerator/src/*.c',
    'mruby_src/mrbgems/mruby-math/src/*.c',
    'mruby_src/mrbgems/mruby-random/src/*.c',
    'mruby_src/mrbgems/mruby-sprintf/src/*.c',
    'mruby_src/mrbgems/mruby-pack/src/*.c',
    'mruby_src/mrbgems/mruby-time/src/*.c',
    'mruby_src/mrbgems/mruby-catch/src/*.c',
    'mruby_src/mrbgems/mruby-encoding/src/*.c',
    'mruby_src/mrbgems/mruby-compiler/core/*.c',
    'mruby_src/mrbgems/mruby-io/src/*.c',
    'mruby_src/mrbgems/mruby-dir/src/*.c',
    'mruby_src/mrbgems/mruby-socket/src/*.c',
    'mruby_src/mrbgems/hal-posix-io/src/*.c',
    'mruby_src/mrbgems/hal-posix-socket/src/*.c',
    'mruby_src/mrbgems/hal-posix-dir/src/*.c',
    'vendor/mruby-onig-regexp/mruby_onig_regexp.c',
    'vendor/mruby-onig-regexp/onigmo/*.c',
    'vendor/mruby-onig-regexp/onigmo/enc/*.c',
    'mruby_src/build_host/mrblib/mrblib.c',
    'mruby_src/build_host/mrbgems/*/gem_init.c'
  ]
  s.exclude_files = 'vendor/mruby-onig-regexp/onigmo/enc/mktable.c'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.libraries = 'm'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/mruby_src/include" "$(PODS_TARGET_SRCROOT)/mruby_src/src" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-io/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-socket/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-dir/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-time/include" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo/enc/unicode" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo/enc/jis"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MRB_UTF8_STRING=1 MRB_USE_BIGINT=1 HAVE_ONIGMO_H=1'
  }
end
