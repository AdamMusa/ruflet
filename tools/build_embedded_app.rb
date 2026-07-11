#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"

entry = ARGV.fetch(0) { abort "usage: build_embedded_app.rb ENTRY.rb OUTPUT.mrb" }
output = ARGV.fetch(1) { abort "usage: build_embedded_app.rb ENTRY.rb OUTPUT.mrb" }
mrbc = Pathname(__dir__).join("..", "ruby_runtime", "third_party", "mruby", "build", "host", "bin", "mrbc").expand_path

def bundle_source(path, seen = {})
  path = Pathname(path).expand_path
  return "" if seen[path]

  seen[path] = true
  path.read.each_line.each_with_object(+<<~RUBY) do |line, source|
    # Bundled relative files execute in the same top-level irep, so startup
    # never needs to compile app source or resolve require_relative.
    RUBY
    if (match = line.match(/^\s*require_relative\s+["']([^"']+)["']/))
      dependency = path.dirname.join(match[1])
      dependency = dependency.sub_ext(".rb") if dependency.extname.empty?
      raise "Missing app dependency: #{dependency}" unless dependency.file?

      source << bundle_source(dependency, seen)
    else
      source << line
    end
  end
end

begin
  source = bundle_source(entry)
  FileUtils.mkdir_p(File.dirname(output))
  temp_source = "#{output}.rb"
  File.write(temp_source, source)

  _stdout, stderr, status = Open3.capture3(mrbc.to_s, "-g", "-o", output, temp_source)
  abort "mrbc failed to compile #{entry}:\n#{stderr}" unless status.success?
ensure
  FileUtils.rm_f(temp_source) if temp_source
end

puts "Wrote #{output} (embedded mruby app bytecode)"
