# frozen_string_literal: true

require_relative "lib/ruflet/version"

Gem::Specification.new do |spec|
  spec.name = "ruflet_protocol"
  spec.version = Ruflet::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "Ruflet protocol package."
  spec.description = "Ruflet protocol primitives and message actions compatible with Flet protocol."
  spec.homepage = "https://github.com/AdamMusa/Ruflet"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]
end
