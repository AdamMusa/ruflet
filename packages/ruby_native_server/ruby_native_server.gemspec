# frozen_string_literal: true

require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native_server"
  spec.version = RubyNative::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "RubyNative server package."
  spec.description = "RubyNative WebSocket server runtime compatible with Flet protocol."
  spec.homepage = "https://github.com/AdamMusa/RubyNative"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_native_protocol", "= #{RubyNative::VERSION}"
  spec.add_dependency "ruby_native_ui", "= #{RubyNative::VERSION}"
  spec.add_dependency "em-websocket", "~> 0.5"
  spec.add_dependency "base64"
  spec.add_dependency "msgpack", "~> 1.8"
end
