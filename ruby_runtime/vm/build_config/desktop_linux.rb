VM_DIR = File.expand_path("..", __dir__)

MRuby::Build.new(ENV.fetch("RUFLET_VM_BUILD", "desktop_linux")) do |conf|
  # GCC miscompiles the large precompiled Ruflet framework on Linux: module
  # constants used by module_function methods resolve as receiver methods at
  # VM initialization. Clang produces the same bytecode payload without that
  # runtime corruption and is also the compiler used by the working Apple VM.
  conf.toolchain :clang
  conf.cc.flags << "-fPIC"
  conf.cxx.flags << "-fPIC"
  conf.gembox "default"
  conf.gem core: "mruby-eval"
  conf.gem core: "mruby-encoding"
  conf.gem core: "mruby-sleep"
  conf.gem File.join(VM_DIR, "mrbgems/mruby-digest")
  conf.gem File.join(VM_DIR, "mrbgems/mruby-onig-regexp")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-record")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-framework")
end
