# Minimal native mrbc used while cross-compiling release VMs.
MRuby::Build.new("host_mrbc") do |conf|
  conf.toolchain
  conf.gem core: "mruby-bin-mrbc"
end
