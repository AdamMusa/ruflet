Pod::Spec.new do |s|
  s.name             = 'ruby_runtime'
  s.version          = '0.0.8'
  s.summary          = 'Embedded Ruby (mruby) VM for Flutter iOS.'
  s.description      = <<-DESC
Embeds a generic mruby VM with gem-loading support ($LOAD_PATH/require) and
exposes start/status/stop over a Flutter method channel. Application
frameworks ship as plain gem file trees in app assets.
                       DESC
  s.homepage         = 'https://github.com/AdamMusa/ruflet'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Izeesoft' => 'dev@izeesoft.com' }
  s.source           = { :path => '.' }

  # Applications compile only this small Flutter bridge. mruby, native gems,
  # and the preloaded Ruflet framework are shipped in the XCFramework.
  s.source_files = [
    'Classes/MrubyRuntimePlugin.{h,m}',
    'Classes/vm_bootstrap.h'
  ]
  s.vendored_frameworks = 'Frameworks/RufletVM.xcframework'

  s.public_header_files = 'Classes/**/*.h'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.libraries = 'm'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/mruby_src/include" "$(PODS_TARGET_SRCROOT)/mruby_src/src" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-io/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-socket/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-dir/include" "$(PODS_TARGET_SRCROOT)/mruby_src/mrbgems/mruby-time/include" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo/enc/unicode" "$(PODS_TARGET_SRCROOT)/vendor/mruby-onig-regexp/onigmo/enc/jis"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MRB_UTF8_STRING=1 MRB_USE_BIGINT=1 HAVE_ONIGMO_H=1'
  }
end
