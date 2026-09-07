VM_DIR = File.expand_path("..", __dir__)

MRuby::CrossBuild.new("desktop_windows") do |conf|
  conf.mrbcfile = ENV["RUFLET_MRBC"] if ENV["RUFLET_MRBC"]
  conf.toolchain :gcc
  conf.host_target = "x86_64-w64-mingw32"
  conf.cc.command = "#{conf.host_target}-gcc-posix"
  conf.cxx.command = "#{conf.host_target}-g++-posix"
  conf.linker.command = conf.cxx.command
  conf.archiver.command = "#{conf.host_target}-gcc-ar"
  conf.exts.executable = ".exe"
  conf.gembox "default"
  conf.gem core: "mruby-eval"
  conf.gem core: "mruby-encoding"
  conf.gem core: "mruby-sleep"
  conf.gem File.join(VM_DIR, "mrbgems/mruby-digest")
  conf.gem File.join(VM_DIR, "mrbgems/mruby-onig-regexp")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-record")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-framework")
end
