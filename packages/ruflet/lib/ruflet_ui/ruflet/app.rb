# frozen_string_literal: true

module Ruflet
  class App
    def initialize(host: "0.0.0.0", port: 8550)
      @host = host
      @port = port
    end

    def run
      Ruflet.run(host: @host, port: @port) do |page|
        view(page)
      end
    end

    def view(_page)
      raise NotImplementedError, "#{self.class} must implement #view(page)"
    end
  end
end
