# frozen_string_literal: true

require_relative "lib/ruflet/version"

Gem::Specification.new do |spec|
  spec.name = "ruflet_cli"
  spec.version = Ruflet::VERSION
  spec.authors = ["AdamMusa"]
  spec.email = ["adammusa2222@gmail.com"]

  spec.summary = "Ruflet CLI package."
  spec.description = "Ruflet command line interface for creating and running Ruflet apps."
  spec.homepage = "https://github.com/AdamMusa/Ruflet"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md", "bin/ruflet"]
  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = ["ruflet"]

  spec.add_dependency "rqrcode", "~> 2.2"
end
