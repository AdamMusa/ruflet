# frozen_string_literal: true

module Ruflet
  class App
    def initialize(host: nil, port: nil)
      @host = (host || ENV["RUFLET_HOST"] || "0.0.0.0")
      @port = normalize_port(port || ENV["RUFLET_PORT"] || 8550)
    end

    def run
      Ruflet.run(host: @host, port: @port) do |page|
        view(page)
      end
    end

    def view(_page)
      raise NotImplementedError, "#{self.class} must implement #view(page)"
    end

    private

    def normalize_port(value)
      port = value.to_i
      port > 0 ? port : 8550
    end
  end
end
