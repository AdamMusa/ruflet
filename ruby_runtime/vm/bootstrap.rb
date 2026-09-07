# frozen_string_literal: true

# Generic mruby VM bootstrap for the ruby_runtime plugin.
#
# This file defines the runtime environment every embedded Ruby app gets:
# feature loading ($LOAD_PATH, require, require_relative), ENV, and small
# language-level polyfills for gaps in the embedded mruby build.
#
# It must stay framework-agnostic: nothing in this file (or in vm/stdlib/)
# may reference Ruflet constants, routes, controls, ports, or any other
# application/framework concern. Framework behavior belongs to the gems the
# VM loads through the ordinary require mechanism.
#
# Native hosts provide three primitives before loading this irep:
#   RubyRuntime.__eval(source, filename)  -- top-level eval with file context
#   RubyRuntime.__load_irep(bytes)        -- run precompiled .mrb bytecode
#   RubyRuntime.__getenv(name)            -- read a process environment value
# When a primitive is missing (e.g. running under a plain host mruby for
# tests), a pure-Ruby fallback is installed where possible.

# Captured for the host-harness eval fallback; harmless when the native
# __eval primitive is present.
$__vm_toplevel_binding = binding if respond_to?(:binding, true)

# mruby's metaprog gem lacks the *_method_defined? predicates.
class Module
  unless method_defined?(:private_method_defined?) || Module.new.respond_to?(:private_method_defined?)
    def private_method_defined?(name)
      private_instance_methods.include?(name.to_sym)
    end

    def public_method_defined?(name)
      public_instance_methods.include?(name.to_sym)
    end

    def protected_method_defined?(name)
      protected_instance_methods.include?(name.to_sym)
    end
  end
end

module RubyRuntime
  class << self
    attr_reader :root, :entrypoint

    # -- native primitive fallbacks (host-mruby test harness) ----------------

    def __ensure_primitives
      unless respond_to?(:__eval)
        define_singleton_method(:__eval) do |source, _filename = nil|
          # Loaded files must see top-level `main` as self, like the native
          # mrb_load_nstring_cxt primitive provides.
          eval(source, $__vm_toplevel_binding) # rubocop:disable Security/Eval -- this *is* the loader
        end
      end
      unless respond_to?(:__load_irep)
        define_singleton_method(:__load_irep) do |_bytes|
          raise LoadError, "this VM build cannot load precompiled bytecode"
        end
      end
      unless respond_to?(:__getenv)
        define_singleton_method(:__getenv) { |_name| nil }
      end
    end

    # -- builtin features (VM stdlib) -----------------------------------------

    def builtin_features
      @builtin_features ||= {}
    end

    def register_builtin(name, &loader)
      builtin_features[name.to_s] = loader
    end

    def load_builtin(name)
      loader = builtin_features[name.to_s]
      return false unless loader

      return true if $LOADED_FEATURES.include?(name.to_s)

      $LOADED_FEATURES << name.to_s
      loader.call
      true
    end

    # -- file loading ----------------------------------------------------------

    def file_stack
      @file_stack ||= []
    end

    def current_file
      file_stack.last
    end

    def current_dir
      file = current_file
      return dirname(file) if file

      root.to_s.empty? ? "." : root
    end

    def load_file(path)
      file_stack.push(path)
      begin
        if path.end_with?(".mrb")
          __load_irep(File.open(path, "rb") { |io| io.read })
        else
          __eval(File.open(path, "rb") { |io| io.read }, path)
        end
      rescue ScriptError => e
        raise ScriptError, "#{path}: #{e.message}"
      ensure
        file_stack.pop
      end
      true
    end

    # Resolve +feature+ against $LOAD_PATH, trying the literal name, then
    # .rb, then precompiled .mrb.
    def resolve_feature(feature)
      candidates =
        if feature.end_with?(".rb") || feature.end_with?(".mrb")
          [feature]
        else
          ["#{feature}.rb", "#{feature}.mrb"]
        end

      if absolute_path?(feature)
        candidates.each do |candidate|
          return candidate if File.file?(candidate)
        end
        return nil
      end

      $LOAD_PATH.each do |dir|
        candidates.each do |candidate|
          path = File.expand_path(candidate, dir)
          return path if File.file?(path)
        end
      end
      nil
    end

    def require_feature(feature)
      feature = feature.to_s
      base = feature.end_with?(".rb") ? feature[0, feature.length - 3] : feature

      return false if $LOADED_FEATURES.include?(base)
      return true if load_builtin(base)

      path = resolve_feature(feature)
      raise LoadError, "cannot load such file -- #{feature}" if path.nil?
      return false if $LOADED_FEATURES.include?(path)

      $LOADED_FEATURES << base
      $LOADED_FEATURES << path
      load_file(path)
    end

    def require_relative_feature(feature)
      feature = feature.to_s
      target = File.expand_path(feature, current_dir)
      target += ".rb" unless target.end_with?(".rb") || target.end_with?(".mrb")
      unless File.file?(target)
        compiled = "#{target[0...-3]}.mrb" if target.end_with?(".rb")
        if compiled && File.file?(compiled)
          target = compiled
        else
          fallback = require_relative_fallback(feature)
          return fallback unless fallback.nil?

          raise LoadError, "cannot load such file -- #{feature}"
        end
      end

      return false if $LOADED_FEATURES.include?(target)

      $LOADED_FEATURES << target
      load_file(target)
    end

    # require_relative called from inside a method resolves lexically in
    # CRuby. Without caller-file introspection the VM approximates that:
    # if a loaded feature's path ends with the relative feature it is the
    # lazy-require-already-loaded case (return false, like CRuby); otherwise
    # fall back to a $LOAD_PATH lookup.
    def require_relative_fallback(feature)
      suffix = feature
      suffix = suffix[2..] while suffix.start_with?("./")
      suffix += ".rb" unless suffix.end_with?(".rb") || suffix.end_with?(".mrb")
      tail = "/#{suffix}"
      return false if $LOADED_FEATURES.any? { |loaded| loaded.end_with?(tail) }

      path = resolve_feature(feature)
      return nil if path.nil?
      return false if $LOADED_FEATURES.include?(path)

      $LOADED_FEATURES << path
      load_file(path)
    end

    # -- lifecycle -------------------------------------------------------------

    def at_exit_blocks
      @at_exit_blocks ||= []
    end

    def run_at_exit_blocks
      while (block = at_exit_blocks.pop)
        begin
          block.call
        rescue StandardError
          nil
        end
      end
    end

    # Entry called by the native host:
    #   RubyRuntime.boot(root, entrypoint, load_paths)
    # +root+ is the extracted project directory, +entrypoint+ the script to
    # run, +load_paths+ the directories require should search (vendored gem
    # lib dirs plus the project root).
    def boot(root, entrypoint, load_paths)
      __ensure_primitives
      @root = root.to_s
      @entrypoint = entrypoint.to_s
      $0 = @entrypoint
      $PROGRAM_NAME = @entrypoint

      Array(load_paths).each do |dir|
        dir = dir.to_s
        $LOAD_PATH << dir unless dir.empty? || $LOAD_PATH.include?(dir)
      end
      $LOAD_PATH << @root unless @root.empty? || $LOAD_PATH.include?(@root)

      load_file(@entrypoint)
    ensure
      run_at_exit_blocks
    end

    # -- small path helpers (no Regexp dependency) -----------------------------

    def absolute_path?(path)
      path.to_s.start_with?("/")
    end

    def dirname(path)
      text = path.to_s
      index = text.rindex("/")
      return "." if index.nil?
      return "/" if index.zero?

      text[0, index]
    end
  end
end

RubyRuntime.__ensure_primitives

$LOAD_PATH ||= []
$LOADED_FEATURES ||= []

# RufletRecord is compiled into device VMs. Its mrbgem initializes before this
# bootstrap, so expose it through the same require contract as the bundled
# Ruflet framework gems.
if Object.const_defined?(:RufletRecord)
  $LOADED_FEATURES << "ruflet_record" unless $LOADED_FEATURES.include?("ruflet_record")
  preloaded_record = "/__preloaded_gems__/ruflet_record.rb"
  $LOADED_FEATURES << preloaded_record unless $LOADED_FEATURES.include?(preloaded_record)
end

# -- ENV ----------------------------------------------------------------------
# Backed by the process environment through the native __getenv primitive.
# Writes are process-local to the VM (they do not call setenv).
unless Object.const_defined?(:ENV) && ENV.respond_to?(:[])
  class EnvironmentMap
    def initialize
      @local = {}
      @deleted = {}
    end

    def [](name)
      key = name.to_s
      return nil if @deleted[key]
      return @local[key] if @local.key?(key)

      RubyRuntime.__getenv(key)
    end

    def []=(name, value)
      key = name.to_s
      @deleted.delete(key)
      if value.nil?
        @deleted[key] = true
        @local.delete(key)
      else
        @local[key] = value.to_s
      end
      value
    end

    def fetch(name, *args)
      value = self[name]
      return value unless value.nil?
      return args[0] unless args.empty?
      return yield(name) if block_given?

      raise KeyError, "key not found: #{name.inspect}"
    end

    def key?(name)
      !self[name].nil?
    end
    alias include? key?
    alias member? key?
    alias has_key? key?

    def delete(name)
      value = self[name]
      self[name] = nil
      value
    end

    def to_hash
      @local.dup
    end
    alias to_h to_hash
  end

  ENV = EnvironmentMap.new
end

# -- language-level polyfills ---------------------------------------------------

unless Object.const_defined?(:LoadError)
  class LoadError < StandardError; end
end

unless Object.const_defined?(:Interrupt)
  class Interrupt < Exception; end
end

class Object
  def eql?(other)
    self == other
  end unless method_defined?(:eql?)
end

class String
  def eql?(other)
    other.is_a?(String) && self == other
  end
end

# mruby only implements `module_function :name`; the widely used no-argument
# form (everything defined afterwards becomes a module function) is missing.
class Module
  unless method_defined?(:__vm_module_function_state) || private_method_defined?(:__vm_module_function_state)
    if method_defined?(:module_function) || private_method_defined?(:module_function)
      alias_method :__vm_orig_module_function, :module_function
    end

    def __vm_module_function_state
      @__vm_module_function_active
    end

    private

    def module_function(*names)
      if names.empty?
        @__vm_module_function_active = true
        return
      end
      names.each { |name| __vm_orig_module_function(name) }
    end

    def method_added(name)
      __vm_orig_module_function(name) if @__vm_module_function_active
      nil
    end
  end
end

module Kernel
  if method_defined?(:rand) || private_method_defined?(:rand)
    alias __vm_native_rand rand unless method_defined?(:__vm_native_rand) || private_method_defined?(:__vm_native_rand)

    def rand(limit = nil)
      if limit.is_a?(Range) && limit.begin.is_a?(Integer) && limit.end.is_a?(Integer)
        first = limit.begin
        last = limit.exclude_end? ? limit.end - 1 : limit.end
        span = last - first + 1
        if span > 0x7fff_ffff
          value = (__vm_native_rand(0x1_0000) << 16) | __vm_native_rand(0x1_0000)
          return first + (value % span)
        end
      end
      limit.nil? ? __vm_native_rand : __vm_native_rand(limit)
    end
    private :rand
  end

  def warn(*messages)
    messages.each { |message| STDERR.puts(message.to_s) }
    nil
  end unless method_defined?(:warn) || private_method_defined?(:warn)

  def require(feature)
    RubyRuntime.require_feature(feature)
  end

  def require_relative(feature)
    RubyRuntime.require_relative_feature(feature)
  end

  def load(path)
    resolved = RubyRuntime.resolve_feature(path.to_s)
    raise LoadError, "cannot load such file -- #{path}" if resolved.nil?

    RubyRuntime.load_file(resolved)
  end

  def __dir__
    RubyRuntime.current_dir
  end

  def at_exit(&block)
    RubyRuntime.at_exit_blocks << block if block
    block
  end

  private :require, :require_relative, :load, :__dir__, :at_exit
end

# The build omits mruby-dir; expose the VM's working directory (the project
# root) which is the only directory embedded apps can rely on.
unless Object.const_defined?(:Dir)
  module Dir
    def self.pwd
      root = RubyRuntime.root.to_s
      root.empty? ? "." : root
    end

    def self.exist?(path)
      File.directory?(path)
    rescue StandardError
      false
    end
  end
end

# Core in CRuby (no require). Clocks are backed by Time.
unless Object.const_defined?(:Process)
  module Process
    CLOCK_REALTIME = 0
    CLOCK_MONOTONIC = 1

    def self.clock_gettime(_clock_id, unit = :float_second)
      now = Time.now.to_f
      case unit
      when :nanosecond then (now * 1_000_000_000).to_i
      when :microsecond then (now * 1_000_000).to_i
      when :millisecond then (now * 1_000).to_i
      when :second then now.to_i
      else now
      end
    end

    def self.pid
      0
    end
  end
end

unless Object.const_defined?(:Signal)
  module Signal
    def self.trap(_signal, handler = nil, &block)
      handler || block
    end
  end
end

module Kernel
  unless method_defined?(:trap) || private_method_defined?(:trap)
    def trap(signal, handler = nil, &block)
      Signal.trap(signal, handler, &block)
    end
    private :trap
  end
end
