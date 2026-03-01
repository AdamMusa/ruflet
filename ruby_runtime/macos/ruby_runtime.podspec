Pod::Spec.new do |s|
  s.name             = 'ruby_runtime'
  s.version          = '0.0.1'
  s.summary          = 'mruby runtime bridge for Flutter macOS.'
  s.description      = <<-DESC
Embeds mruby in native macOS code and exposes eval/runFile/reset over a Flutter method channel.
                       DESC
  s.homepage         = 'https://example.com/ruby_runtime'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Izeesoft' => 'dev@izeesoft.com' }

  s.source = { :path => '.' }
  s.source_files = [
    'Classes/**/*.{h,m,mm,c,cc,cpp}',
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
    'mruby_src/mrbgems/hal-posix-io/src/io_hal.c',
    'mruby_src/mrbgems/hal-posix-socket/src/socket_hal.c',
    'mruby_src/build_host/mrblib/mrblib.c',
    'mruby_src/build_host/mrbgems/mruby-errno/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-io/gem_init.c',
    'mruby_src/build_host/mrbgems/mruby-socket/gem_init.c'
  ]

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.libraries = 'm'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/mruby_src/include" "$(PODS_TARGET_SRCROOT)/mruby_src/src" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-compiler/core" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-io/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-socket/include"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MRB_NO_PRESYM=1'
  }
end
