# frozen_string_literal: true

require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native_cli"
  spec.version = RubyNative::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "RubyNative CLI package."
  spec.description = "RubyNative command line interface for creating and running RubyNative apps."
  spec.homepage = "https://github.com/AdamMusa/RubyNative"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md", "bin/ruby_native"]
  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = ["ruby_native"]

  spec.add_dependency "ruby_native_server", "= #{RubyNative::VERSION}"
end
