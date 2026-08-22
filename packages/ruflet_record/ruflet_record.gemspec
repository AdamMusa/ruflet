# frozen_string_literal: true

require_relative "lib/ruflet_record/version"

Gem::Specification.new do |spec|
  spec.name = "ruflet_record"
  spec.version = RufletRecord::VERSION
  spec.authors = ["Adam Moussa Ali"]
  spec.email = ["adammusaaly@gmail.com"]

  spec.summary = "A tiny SQLite record mapper for Ruflet and mruby."
  spec.description = "Active Record-shaped models, relations, schema tools, and SQLite persistence for Ruflet applications on CRuby and mruby."
  spec.homepage = "https://github.com/AdamMusa/Ruflet/tree/main/packages/ruflet_record"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3", ">= 2.0"
end
