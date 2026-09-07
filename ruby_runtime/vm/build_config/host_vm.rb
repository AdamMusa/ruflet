# Host build of the embedded VM's Ruby surface.
#
# Produces build/host_vm/bin/mruby with the same gem set the device VMs link
# (core stdlib + IO/socket + Regexp + Digest), so gem and app compatibility
# can be verified on the development machine without a Flutter build.
#
#   cd ruby_runtime/third_party/mruby
#   rake MRUBY_CONFIG=../../vm/build_config/host_vm.rb

VM_DIR = File.expand_path("..", __dir__)

MRuby::Build.new("host_vm") do |conf|
  conf.toolchain

  conf.gembox "default"

  conf.gem core: "mruby-eval"
  conf.gem core: "mruby-encoding"
  conf.gem core: "mruby-sleep"

  conf.gem File.join(VM_DIR, "mrbgems/mruby-digest")
  conf.gem File.join(VM_DIR, "mrbgems/mruby-onig-regexp")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-record")
  conf.gem File.join(VM_DIR, "mrbgems/ruflet-framework")

  conf.enable_debug
end
