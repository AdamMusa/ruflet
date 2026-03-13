# frozen_string_literal: true

require_relative "lib/ruflet/version"

Gem::Specification.new do |spec|
  spec.name = "ruflet"
  spec.version = Ruflet::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "Ruflet umbrella package."
  spec.description = "Ruflet umbrella package that installs the core runtime, server runtime, and CLI."
  spec.homepage = "https://github.com/AdamMusa/Ruflet"
  spec.required_ruby_version = ">= 3.1"

  spec.files = [
    "lib/ruflet.rb",
    "lib/ruflet/version.rb",
    "README.md"
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruflet_cli", "= #{Ruflet::VERSION}"
  spec.add_dependency "ruflet_core", "= #{Ruflet::VERSION}"
  spec.add_dependency "ruflet_server", "= #{Ruflet::VERSION}"
end
