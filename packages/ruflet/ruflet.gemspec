# frozen_string_literal: true

require_relative "lib/ruflet/version"

Gem::Specification.new do |spec|
  spec.name = "ruflet_core"
  spec.version = Ruflet::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "Ruflet core runtime package."
  spec.description = "Ruflet core runtime with the Ruby DSL, controls, protocol, and page runtime."
  spec.homepage = "https://github.com/AdamMusa/Ruflet"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]
end
