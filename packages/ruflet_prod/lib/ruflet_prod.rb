# frozen_string_literal: true

require_relative "ruflet_prod/version"
require_relative "ruflet_prod/json_parser"
require_relative "ruflet_prod/protocol"
require_relative "ruflet_prod/wire_codec"
require_relative "ruflet_prod/web_socket_connection"
require_relative "ruflet_prod/server"

module RufletProd
  module_function

  def run(host: "0.0.0.0", port: 8550, manifest: nil, manifest_file: nil)
    loaded_manifest = manifest || load_manifest_from_file(manifest_file || ENV["RUFLET_MANIFEST_FILE"])
    raise ArgumentError, "RufletProd.run requires :manifest or :manifest_file" unless loaded_manifest.is_a?(Hash)

    Server.new(host: host, port: port, manifest: loaded_manifest).start
  end

  def load_manifest_from_file(path)
    manifest_path = path.to_s
    return nil if manifest_path.empty?
    raise ArgumentError, "Manifest file not found: #{manifest_path}" unless File.file?(manifest_path)

    RufletProd::JsonParser.parse(File.read(manifest_path))
  end
end
