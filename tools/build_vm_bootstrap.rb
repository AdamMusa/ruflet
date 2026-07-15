#!/usr/bin/env ruby
# frozen_string_literal: true

# Compiles the generic VM bootstrap (ruby_runtime/vm/bootstrap.rb + stdlib
# features) to mruby bytecode headers the native plugins embed. The bootstrap
# is framework-agnostic; Ruflet gems ship separately as app assets and load
# through the bootstrap's require machinery.

require "fileutils"
require "open3"
require "pathname"
require_relative "vm_bootstrap_bundle"

ROOT = Pathname(__dir__).join("..").expand_path
# Must match the mruby version + RITE format of the platform VMs (3.4 / RITE0400).
MRBC = ROOT.join("ruby_runtime/third_party/mruby/build/host/bin/mrbc")

TARGET_HEADERS = [
  ROOT.join("ruby_runtime/shared/vm_bootstrap.h"),
  ROOT.join("ruby_runtime/macos/Classes/vm_bootstrap.h"),
  ROOT.join("ruby_runtime/ios/Classes/vm_bootstrap.h"),
  ROOT.join("ruby_runtime/android/src/main/cpp/vm_bootstrap.h")
].freeze

raise "mrbc not found at #{MRBC}; build the vendored mruby first" unless MRBC.executable?

compile_dir = ROOT.join("build/vm_bootstrap")
FileUtils.mkdir_p(compile_dir)
begin
  src = compile_dir.join("vm_bootstrap.rb")
  out = compile_dir.join("vm_bootstrap.h")
  src.write(VmBootstrapBundle.source)

  # -g keeps file/line info so runtime errors in the bootstrap are traceable.
  _stdout, stderr, status = Open3.capture3(MRBC.to_s, "-g", "-B", "kRubyRuntimeVmBootstrapIrep", "-o", out.to_s, src.to_s)
  raise "mrbc failed to compile the VM bootstrap:\n#{stderr}" unless status.success?

  header = "#pragma once\n\n#{out.read}"
  TARGET_HEADERS.each do |target|
    FileUtils.mkdir_p(target.dirname)
    target.write(header)
    puts "Wrote #{target.relative_path_from(ROOT)}"
  end
ensure
  FileUtils.rm_rf(compile_dir)
end
