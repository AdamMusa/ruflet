# frozen_string_literal: true

require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native_ui"
  spec.version = RubyNative::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "RubyNative UI/DSL package."
  spec.description = "RubyNative UI widgets and DSL, ported from Flet semantics."
  spec.homepage = "https://github.com/AdamMusa/RubyNative"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_native_protocol", "= #{RubyNative::VERSION}"
end
