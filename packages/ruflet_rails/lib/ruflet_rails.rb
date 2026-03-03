# frozen_string_literal: true

local_ruflet_lib = File.expand_path("../../ruflet/lib", __dir__)
if File.directory?(local_ruflet_lib) && !$LOAD_PATH.include?(local_ruflet_lib)
  $LOAD_PATH.unshift(local_ruflet_lib)
end

require "ruflet"
require_relative "ruflet/rails/protocol"
require_relative "ruflet/rails"

if defined?(::Rails::Railtie)
  require_relative "ruflet/rails/railtie"
end
