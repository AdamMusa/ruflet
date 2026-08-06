Pod::Spec.new do |s|
  s.name             = 'ruby_runtime'
  s.version          = '0.0.13'
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
  # mruby, its native gems, Onigmo, the VM host layer and Ruflet are already
  # inside this archive, reached through the four ruflet_vm_* entry points in
  # desktop/ruflet_vm_host.h -- the same header every platform bridges to.
  s.source_files = [
    'Classes/RubyRuntimeMacosPlugin.{h,m}'
  ]
  # apple/ holds the platform-side startup shared with iOS; desktop/ holds the
  # VM entry points shared with every platform.
  s.preserve_paths = ['../desktop/ruflet_vm_host.h', '../apple/*.h']
  s.vendored_libraries = 'Frameworks/libruflet_vm.a'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  # The VM host layer inside the archive is C++, so the bridge links libc++.
  s.libraries = 'm', 'c++'
  # The bridge only needs ruflet_vm_host.h. mruby, Onigmo and the native gems
  # are compiled into the archive, so no mruby headers or build defines are
  # required here and none of those sources ship in the package.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/../desktop" "$(PODS_TARGET_SRCROOT)/../apple"'
  }
end
