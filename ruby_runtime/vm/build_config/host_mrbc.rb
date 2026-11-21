# Minimal native mrbc used while cross-compiling release VMs.

require_relative "../patches/mruby_patches"
RufletMrubyPatches.apply(MRUBY_ROOT)

MRuby::Build.new("host_mrbc") do |conf|
  conf.toolchain
  conf.gem core: "mruby-bin-mrbc"
end
