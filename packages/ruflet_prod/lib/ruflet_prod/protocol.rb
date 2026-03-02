# frozen_string_literal: true

module RufletProd
  module Protocol
    ACTIONS = {
      register_client: 1,
      patch_control: 2,
      control_event: 3,
      update_control: 4,
      invoke_control_method: 5,
      session_crashed: 6,
      register_web_client: "registerWebClient",
      page_event_from_web: "pageEventFromWeb",
      update_control_props: "updateControlProps"
    }.freeze

    def self.normalize_register_payload(payload)
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

    def self.normalize_control_event_payload(payload)
      {
        "target" => payload["target"] || payload["eventTarget"],
        "name" => payload["name"] || payload["eventName"],
        "data" => payload["data"] || payload["eventData"]
      }
    end

    def self.normalize_update_control_payload(payload)
      {
        "id" => payload["id"] || payload["target"] || payload["eventTarget"],
        "props" => payload["props"].is_a?(Hash) ? payload["props"] : {}
      }
    end
  end
end
