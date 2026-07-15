# frozen_string_literal: true

# Assembles the generic VM bootstrap: ruby_runtime/vm/bootstrap.rb plus every
# feature under ruby_runtime/vm/stdlib/ wrapped as a lazily-loaded builtin.
# The result is what native hosts compile into the vm_bootstrap header and
# what the host test harness feeds to the host_vm mruby build.
module VmBootstrapBundle
  VM_DIR = File.expand_path("../ruby_runtime/vm", __dir__)
  STDLIB_DIR = File.join(VM_DIR, "stdlib")

  module_function

  def bootstrap_path
    File.join(VM_DIR, "bootstrap.rb")
  end

  def stdlib_features
    Dir.glob(File.join(STDLIB_DIR, "**", "*.rb")).sort.map do |path|
      feature = path.sub("#{STDLIB_DIR}/", "").sub(/\.rb\z/, "")
      [feature, path]
    end
  end

  # The onig-regexp C gem is linked into the device VMs, but its Ruby layer
  # (String#gsub etc. rebound to the onig implementation) normally loads via
  # the mrbgem build. Device plugins don't run mrbgem mrblibs, so it ships in
  # the bootstrap, guarded so builds that already loaded it (host_vm) skip it.
  def onig_regexp_ruby_layer
    path = File.join(VM_DIR, "mrbgems/mruby-onig-regexp/mrblib/onig_regexp.rb")
    <<~RUBY
      # -- Regexp ruby layer (mruby-onig-regexp mrblib)
      if Object.const_defined?(:OnigRegexp) &&
         !(Object.const_defined?(:OnigMatchData) && OnigMatchData.method_defined?(:named_captures))
      #{File.read(path)}
      end
    RUBY
  end

  def source
    parts = [onig_regexp_ruby_layer, File.read(bootstrap_path)]
    stdlib_features.each do |feature, path|
      parts << <<~RUBY
        # -- builtin feature: #{feature}
        RubyRuntime.register_builtin(#{feature.inspect}) do
        #{File.read(path)}
        end
      RUBY
    end
    parts.join("\n")
  end
end
