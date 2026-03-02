# frozen_string_literal: true

require "json"
require "time"

module Ruflet
  module ManifestCompiler
    module_function

    def compile_app(app, route: "/")
      messages = []
      sender = lambda do |action, payload|
        messages << { "action" => action, "payload" => payload }
      end

      page = Ruflet::Page.new(
        session_id: "manifest",
        client_details: { "route" => route.to_s.empty? ? "/" : route.to_s },
        sender: sender
      )

      app.view(page)
      page.update

      compacted = compact_messages(messages)

      {
        "schema" => "ruflet_manifest/v1",
        "generated_at" => Time.now.utc.iso8601,
        "route" => page.route || "/",
        "messages" => compacted
      }
    end

    def write_file(path, manifest)
      File.write(path, JSON.pretty_generate(manifest))
      path
    end

    def read_file(path)
      JSON.parse(File.read(path.to_s))
    end

    def compact_messages(messages)
      full_patch_index = nil
      messages.each_with_index do |message, idx|
        next unless message["action"] == Ruflet::Protocol::ACTIONS[:patch_control]

        payload = message["payload"] || {}
        next unless payload["id"] == 1

        patch = payload["patch"]
        next unless patch.is_a?(Array) && patch.any? { |op| op.is_a?(Array) && op[2] == "views" }

        full_patch_index = idx
      end
      return messages if full_patch_index.nil?

      [messages[full_patch_index]]
    end
  end
end
