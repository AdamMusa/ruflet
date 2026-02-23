# frozen_string_literal: true

require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native_protocol"
  spec.version = RubyNative::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "RubyNative protocol package."
  spec.description = "RubyNative protocol primitives and message actions compatible with Flet protocol."
  spec.homepage = "https://github.com/AdamMusa/RubyNative"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]
end
