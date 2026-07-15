# Ruflet framework files are compiled into this mrbgem in dependency order.
# Their source-level require calls are therefore already satisfied while the
# mrbgem initializes. The generic VM bootstrap replaces these methods before
# developer application code runs.
module Kernel
  def require(_feature)
    false
  end

  def require_relative(_feature)
    false
  end

  # mruby does not expose source-file introspection. Framework resources are
  # resolved by the runtime after bootstrap; this keeps class/module loading
  # independent from an application payload path.
  def __dir__
    "."
  end
end

class Module
  unless method_defined?(:__ruflet_vm_original_module_function)
    alias_method :__ruflet_vm_original_module_function, :module_function

    def module_function(*names)
      if names.empty?
        @__ruflet_vm_module_function = true
      else
        names.each { |name| __ruflet_vm_original_module_function(name) }
      end
    end

    # Signals the generic bootstrap that the VM-level no-argument
    # module_function implementation is already installed.
    def __vm_module_function_state
      @__ruflet_vm_module_function
    end

    def method_added(name)
      __ruflet_vm_original_module_function(name) if @__ruflet_vm_module_function
      nil
    end
  end
end

class Array
  def to_set
    Set.new(self)
  end unless method_defined?(:to_set)
end

# mruby-io exposes instance IO#write but omits Ruby's commonly used File class
# helpers. Developer applications should not need mruby-specific file code.
class File
  class << self
    def write(path, content, offset = nil, **options)
      mode = options[:mode] || "w"
      open(path, mode) do |file|
        file.seek(offset) unless offset.nil?
        file.write(content)
      end
    end unless respond_to?(:write)

    def binwrite(path, content, offset = nil)
      write(path, content, offset, mode: "wb")
    end unless respond_to?(:binwrite)

    def binread(path, length = nil, offset = 0)
      open(path, "rb") do |file|
        file.seek(offset) unless offset.nil? || offset == 0
        length.nil? ? file.read : file.read(length)
      end
    end unless respond_to?(:binread)
  end
end

$LOADED_FEATURES ||= []
%w[ruflet ruflet_core ruflet_server].each do |feature|
  $LOADED_FEATURES << feature unless $LOADED_FEATURES.include?(feature)
end
