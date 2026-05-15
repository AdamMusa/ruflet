# frozen_string_literal: true

%w[ruflet_core ruflet].reverse_each do |package|
  local_package_lib = File.expand_path("../../#{package}/lib", __dir__)
  if File.directory?(local_package_lib) && !$LOAD_PATH.include?(local_package_lib)
    $LOAD_PATH.unshift(local_package_lib)
  end
end

require "ruflet_core"
require_relative "ruflet/rails/protocol"
require_relative "ruflet/rails/install_support"
require_relative "ruflet/rails"

if defined?(::Rails::Railtie)
  require_relative "ruflet/rails/railtie"
end
