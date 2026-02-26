# frozen_string_literal: true

require "ruflet"
require_relative "ruflet/rails/protocol"
require_relative "ruflet/rails"

if defined?(::Rails::Railtie)
  require_relative "ruflet/rails/railtie"
end
