# frozen_string_literal: true

%w[ruflet_core ruflet_server ruflet].reverse_each do |package|
  local_package_lib = File.expand_path("../../#{package}/lib", __dir__)
  if File.directory?(local_package_lib) && !$LOAD_PATH.include?(local_package_lib)
    $LOAD_PATH.unshift(local_package_lib)
  end
end

require "ruflet_core"
require "ruflet_server"
require_relative "ruflet/rails/session_registry"
require_relative "ruflet/rails/native_app"
require_relative "ruflet/rails/view_helpers"
require_relative "ruflet/rails/desktop_launcher"
require_relative "ruflet/rails/protocol"
require_relative "ruflet/rails/assets"
require_relative "ruflet/rails/web_installer"
require_relative "ruflet/rails/configuration"
require_relative "ruflet/rails/install_support"
require_relative "ruflet/rails"

if defined?(::Rails::Railtie)
  require_relative "ruflet/rails/railtie"
end
