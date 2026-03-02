# frozen_string_literal: true
require_relative "../../ruflet/manifest_compiler"

module Ruflet
  class App
    def initialize(host: "0.0.0.0", port: 8550)
      @host = host
      @port = port
    end

    def run
      manifest_out = ENV["RUFLET_MANIFEST_OUT"].to_s
      unless manifest_out.empty?
        route = ENV["RUFLET_MANIFEST_ROUTE"].to_s
        route = "/" if route.empty?
        manifest = Ruflet::ManifestCompiler.compile_app(self, route: route)
        Ruflet::ManifestCompiler.write_file(manifest_out, manifest)
        puts manifest_out
        return manifest_out
      end

      Ruflet.run(host: @host, port: @port) do |page|
        view(page)
      end
    end

    def view(_page)
      raise NotImplementedError, "#{self.class} must implement #view(page)"
    end
  end
end
