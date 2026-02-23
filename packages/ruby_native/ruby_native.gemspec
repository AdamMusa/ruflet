# frozen_string_literal: true

require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native"
  spec.version = RubyNative::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "RubyNative umbrella package."
  spec.description = "RubyNative is a library that allows building web, desktop and mobile applications in Ruby without prior experience in frontend development."
  spec.homepage = "https://github.com/AdamMusa/RubyNative"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_native_protocol", "= #{RubyNative::VERSION}"
  spec.add_dependency "ruby_native_ui", "= #{RubyNative::VERSION}"
  spec.add_dependency "ruby_native_server", "= #{RubyNative::VERSION}"
  spec.add_dependency "ruby_native_cli", "= #{RubyNative::VERSION}"
end
