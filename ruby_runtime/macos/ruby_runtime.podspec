Pod::Spec.new do |s|
  s.name             = 'ruby_runtime'
  s.version          = '0.0.8'
  s.summary          = 'Embedded Ruby (mruby) VM for Flutter macOS.'
  s.description      = <<-DESC
Links the packaged Ruflet mruby VM and exposes start/status/stop over a
Flutter method channel. Application code ships as an app asset payload.
                       DESC
  s.homepage         = 'https://github.com/AdamMusa/ruflet'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Izeesoft' => 'dev@izeesoft.com' }

  s.source = { :path => '.' }
  # The Flutter bridge is the only native source compiled by an application.
  # mruby, its native gems, Onigmo, and Ruflet are already inside this archive.
  s.source_files = [
    'Classes/RubyRuntimeMacosPlugin.{h,m}',
    'Classes/vm_bootstrap.h'
  ]
  s.vendored_libraries = 'Frameworks/libruflet_vm.a'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.libraries = 'm'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/mruby_src/include" "$(PODS_TARGET_SRCROOT)/mruby_src/src" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-io/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-socket/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-dir/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-time/include" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo/enc/unicode" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo/enc/jis"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MRB_UTF8_STRING=1 MRB_USE_BIGINT=1 HAVE_ONIGMO_H=1'
  }
end
