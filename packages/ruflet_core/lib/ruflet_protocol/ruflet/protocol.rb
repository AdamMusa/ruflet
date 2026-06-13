# frozen_string_literal: true

module Ruflet
  module Protocol
    ACTIONS = {
      register_client: 1,
      patch_control: 2,
      control_event: 3,
      update_control: 4,
      invoke_control_method: 5,
      session_crashed: 6,
      python_output: 7,

      # Legacy JSON protocol aliases kept for compatibility.
      register_web_client: "registerWebClient",
      page_event_from_web: "pageEventFromWeb",
      update_control_props: "updateControlProps"
    }.freeze

    module_function

    def pack_message(action:, payload:)
      [action_code(action), payload]
    end

    def action_code(action)
      return action if action.is_a?(Integer) || action.is_a?(String)

      ACTIONS.fetch(action)
    end

    def normalize_register_payload(payload)
      page = payload["page"] || {}
      {
        "session_id" => payload["session_id"],
        "page_name" => payload["page_name"] || "",
        "route" => page["route"] || "/",
        "width" => page["width"],
        "height" => page["height"],
        "platform" => page["platform"],
        "platform_brightness" => page["platform_brightness"],
        # The Flutter client reports the host OS in "platform" even inside a
        # browser, so "web" is the only reliable way to tell a web client from a
        # native one. (pwa/wasm passed through for completeness.)
        "web" => page["web"],
        "pwa" => page["pwa"],
        "wasm" => page["wasm"],
        "media" => page["media"] || {}
      }
    end

    def normalize_control_event_payload(payload)
      {
        "target" => payload["target"] || payload["eventTarget"],
        "name" => payload["name"] || payload["eventName"],
        "data" => payload["data"] || payload["eventData"]
      }
    end

    def normalize_update_control_payload(payload)
      {
        "id" => payload["id"] || payload["target"] || payload["eventTarget"],
        "props" => payload["props"].is_a?(Hash) ? payload["props"] : {}
      }
    end

    def normalize_patch_control_payload(payload)
      {
        "id" => payload["id"] || payload[:id],
        "patch" => Array(payload["patch"] || payload[:patch])
      }
    end

    def normalize_invoke_method_payload(payload)
      {
        "control_id" => payload["control_id"] || payload[:control_id],
        "call_id" => payload["call_id"] || payload[:call_id],
        "name" => payload["name"] || payload[:name],
        "args" => payload.key?("args") ? payload["args"] : payload[:args],
        "timeout" => payload.key?("timeout") || payload.key?(:timeout) ? (payload["timeout"] || payload[:timeout]) : 10
      }
    end

    def normalize_invoke_method_result_payload(payload)
      {
        "control_id" => payload["control_id"] || payload[:control_id],
        "call_id" => payload["call_id"] || payload[:call_id],
        "result" => payload.key?("result") ? payload["result"] : payload[:result],
        "error" => payload.key?("error") ? payload["error"] : payload[:error]
      }
    end

    def normalize_session_crashed_payload(payload)
      {
        "message" => payload["message"] || payload[:message].to_s
      }
    end

    def normalize_python_output_payload(payload)
      {
        "text" => payload["text"] || payload[:text].to_s,
        "is_stderr" => payload.key?("is_stderr") || payload.key?(:is_stderr) ? !!(payload["is_stderr"] || payload[:is_stderr]) : false
      }
    end

    def register_response(session_id:, page_patch: nil, error: nil)
      page_patch ||= {}
      {
        "session_id" => session_id,
        "page_patch" => page_patch,
        "error" => error
      }
    end
  end
end
