# frozen_string_literal: true

module Ruflet
  module Protocol
    # Flet transports these values as MessagePack extension objects. String
    # subclasses preserve Ruflet's existing, convenient Ruby API while giving
    # the wire codec the type information required by the Flutter client.
    class DateTimeValue < String; end
    class TimeOfDayValue < String; end
    class DurationValue < String; end

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

    def date_time(value)
      return value if value.nil? || value.is_a?(DateTimeValue)

      DateTimeValue.new(value.to_s)
    end

    def time_of_day(value)
      return value if value.nil? || value.is_a?(TimeOfDayValue)

      TimeOfDayValue.new(value.to_s)
    end

    def duration(value)
      return value if value.nil? || value.is_a?(DurationValue)

      DurationValue.new(value.to_s)
    end

    def pack_message(action:, payload:)
      [action, payload]
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
        "window" => page["window"] || {},
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

    # The client's reply to `invoke_control_method`: the pending call id plus its
    # result/error. Ruflet::ConnectionProtocol (ruflet_rails' Rack-hijack adapter
    # and any other host adapter) normalizes this before handing it to
    # Page#handle_invoke_method_result, which matches `call_id` back to the
    # waiting callback. Without this method that path fell through to the DSL's
    # method_missing and every invoke result was silently discarded.
    def normalize_invoke_method_result_payload(payload)
      payload = {} unless payload.is_a?(Hash)
      {
        "call_id" => payload["call_id"] || payload["callId"],
        "result" => payload.key?("result") ? payload["result"] : payload["value"],
        "error" => payload["error"]
      }
    end

    # page_patch defaults to nil rather than {} because mruby cannot parse a
    # hash literal as a keyword argument default, and this file is compiled
    # into the embedded VM.
    def register_response(session_id:, page_patch: nil)
      {
        "session_id" => session_id,
        "page_patch" => page_patch || {},
        "error" => ""
      }
    end
  end
end
