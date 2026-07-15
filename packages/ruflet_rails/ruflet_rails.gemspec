# frozen_string_literal: true

version = File.read(File.expand_path("lib/ruflet/version.rb", __dir__)).match(/VERSION = "([^"]+)"/)[1]

Gem::Specification.new do |spec|
  spec.name = "ruflet_rails"
  spec.version = version
  spec.authors = ["Adam Moussa Ali"]
  spec.email = ["adammusaaly@gmail.com"]

  spec.summary = "Rails integration for Ruflet."
  spec.description = "Build cross-platform mobile and desktop apps with Ruby on Rails using Ruflet."
  spec.homepage = "https://github.com/AdamMusa/ruflet/tree/main/packages/ruflet_rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "ruflet", ">= 0.0.19"
  spec.add_dependency "ruflet_core", ">= 0.0.19"
  spec.add_dependency "ruflet_server", ">= 0.0.19"
end
