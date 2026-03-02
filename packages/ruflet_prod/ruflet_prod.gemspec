# frozen_string_literal: true

require_relative "lib/ruflet_prod/version"

Gem::Specification.new do |spec|
  spec.name = "ruflet_prod"
  spec.version = RufletProd::VERSION
  spec.authors = ["Izeesoft"]
  spec.email = ["dev@izeesoft.com"]

  spec.summary = "RufletProd lightweight manifest runtime."
  spec.description = "RufletProd serves prebuilt Ruflet manifest JSON over a minimal protocol/server."
  spec.homepage = "https://github.com/AdamMusa/Ruflet"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md"]
  spec.require_paths = ["lib"]

end
