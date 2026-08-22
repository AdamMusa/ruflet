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
  # the VM host layer and the preloaded Ruflet framework are shipped in the
  # XCFramework, reached through the four ruflet_vm_* entry points in
  # desktop/ruflet_vm_host.h -- the same header every platform bridges to.
  s.source_files = [
    'Classes/MrubyRuntimePlugin.{h,m}'
  ]
  s.preserve_paths = ['../desktop/*.h', '../apple/*.h']
  s.vendored_frameworks = 'Frameworks/RufletVM.xcframework'

  # vm_bootstrap.h is compiled into the vendored VM host and must not appear
  # in CocoaPods' generated umbrella header.
  s.public_header_files = 'Classes/MrubyRuntimePlugin.h'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  # The VM host layer inside the archive is C++, so the bridge links libc++.
  s.libraries = 'm', 'c++'

  # The bridge only needs ruflet_vm_host.h. mruby, Onigmo and the native gems
  # are compiled into the XCFramework, so no mruby headers or build defines are
  # required here and none of those sources ship in the package.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/../desktop" "$(PODS_TARGET_SRCROOT)/../apple"'
  }
end
