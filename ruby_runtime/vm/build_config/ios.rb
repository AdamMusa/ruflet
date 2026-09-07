VM_DIR = File.expand_path("..", __dir__)

sdk = ENV.fetch("RUFLET_IOS_SDK")
arch = ENV.fetch("RUFLET_IOS_ARCH")
build_name = ENV.fetch("RUFLET_VM_BUILD", "ios_#{sdk}_#{arch}")
minimum_version_flag =
  sdk == "iphoneos" ? "-miphoneos-version-min=13.0" : "-mios-simulator-version-min=13.0"

MRuby::CrossBuild.new(build_name) do |conf|
  conf.mrbcfile = ENV.fetch("RUFLET_MRBC")
  conf.toolchain :clang
  conf.cc.command = "xcrun --sdk #{sdk} clang"
  conf.cxx.command = "xcrun --sdk #{sdk} clang++"
  conf.linker.command = conf.cxx.command
  conf.archiver.command = "xcrun --sdk #{sdk} ar"
  conf.cc.flags << "-arch" << arch << minimum_version_flag << "-fPIC"
  conf.cxx.flags << "-arch" << arch << minimum_version_flag << "-fPIC"
  conf.linker.flags << "-arch" << arch << minimum_version_flag
  conf.gembox "default"
  conf.gem core: "mruby-eval"
  conf.gem core: "mruby-encoding"
  conf.gem core: "mruby-sleep"
  conf.gem File.join(VM_DIR, "mrbgems/mruby-digest")
  conf.gem File.join(VM_DIR, "mrbgems/mruby-onig-regexp")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-record")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-framework")
end
