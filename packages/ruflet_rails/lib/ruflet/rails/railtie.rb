# frozen_string_literal: true

module Ruflet
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "ruflet_rails.middleware" do |app|
        app.middleware.use Ruflet::Rails::Protocol::Middleware
      end
    end
  end
end
