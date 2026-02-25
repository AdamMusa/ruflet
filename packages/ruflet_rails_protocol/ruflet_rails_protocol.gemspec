# frozen_string_literal: true

require_relative "lib/ruflet/version"

Gem::Specification.new do |spec|
  spec.name = "ruflet_rails_protocol"
  spec.version = Ruflet::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "Rails WebSocket protocol adapter for Ruflet."
  spec.description = "Provides Rack/WebSocket bridge and mobile loader used by ruflet_rails."
  spec.homepage = "https://github.com/AdamMusa/Ruflet"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruflet", "= #{Ruflet::VERSION}"
end
