VM_DIR = File.expand_path("..", __dir__)
ARCH = ENV.fetch("RUFLET_VM_ARCH")
raise "Unsupported macOS VM architecture: #{ARCH}" unless %w[arm64 x86_64].include?(ARCH)

MRuby::Build.new("desktop_macos_#{ARCH}") do |conf|
  conf.toolchain :clang
  conf.cc.flags.delete("-g")
  conf.cxx.flags.delete("-g")
  conf.cc.flags << "-arch" << ARCH << "-mmacosx-version-min=10.14"
  conf.cxx.flags << "-arch" << ARCH << "-mmacosx-version-min=10.14"
  conf.linker.flags << "-arch" << ARCH << "-mmacosx-version-min=10.14"
  conf.gembox "default"
  conf.gem core: "mruby-eval"
  conf.gem core: "mruby-encoding"
  conf.gem core: "mruby-sleep"
  conf.gem File.join(VM_DIR, "mrbgems/mruby-digest")
  conf.gem File.join(VM_DIR, "mrbgems/mruby-onig-regexp")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-framework")
end
