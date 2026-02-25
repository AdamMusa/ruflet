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

      # Legacy JSON protocol aliases kept for compatibility.
      register_web_client: "registerWebClient",
      page_event_from_web: "pageEventFromWeb",
      update_control_props: "updateControlProps"
    }.freeze

    module_function

    def pack_message(action:, payload:)
      [action, payload]
    end

    def normalize_register_payload(payload)
      # New protocol payload shape:
      # {"session_id"=>..., "page_name"=>..., "page"=>{...}}
      page = payload["page"] || {}
      {
        "session_id" => payload["session_id"],
        "page_name" => payload["page_name"] || "",
        "route" => page["route"] || "/",
        "width" => page["width"],
        "height" => page["height"],
        "platform" => page["platform"],
        "platform_brightness" => page["platform_brightness"],
        "media" => page["media"] || {}
      }
    end

    def register_response(session_id:)
      {
        "session_id" => session_id,
        "page_patch" => {},
        "error" => nil
      }
    end
  end
end
