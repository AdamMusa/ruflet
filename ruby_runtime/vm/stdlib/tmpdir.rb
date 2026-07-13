# frozen_string_literal: true

require "fileutils"

# Defined with `def Dir.` so this works whether Dir is the mruby-dir class or
# the bootstrap fallback module.
def Dir.tmpdir
  candidate = ENV["TMPDIR"] || ENV["TMP"] || ENV["TEMP"]
  return candidate.chomp("/") if candidate && !candidate.to_s.empty?

  fallback = "#{pwd.chomp('/')}/tmp"
  FileUtils.mkdir_p(fallback) unless File.directory?(fallback)
  fallback
end

def Dir.mktmpdir(prefix = "d")
  base = "#{tmpdir}/#{prefix}#{rand(0xffffffff).to_s(16)}"
  FileUtils.mkdir_p(base)
  if block_given?
    yield base
  else
    base
  end
end
