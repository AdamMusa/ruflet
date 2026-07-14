VM_DIR = File.expand_path("..", __dir__)

MRuby::Build.new(ENV.fetch("RUFLET_VM_BUILD", "desktop_linux")) do |conf|
  conf.toolchain :gcc
  conf.cc.flags << "-fPIC"
  conf.cxx.flags << "-fPIC"
  conf.gembox "default"
  conf.gem core: "mruby-eval"
  conf.gem core: "mruby-encoding"
  conf.gem core: "mruby-sleep"
  conf.gem File.join(VM_DIR, "mrbgems/mruby-digest")
  conf.gem File.join(VM_DIR, "mrbgems/mruby-onig-regexp")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-framework")
end
