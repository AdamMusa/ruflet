# frozen_string_literal: true

module Ruflet
  module Rails
    class NativeApp
      private

      # --- Declared actions --------------------------------------------------

      # Route a `data-ruflet-action` element to native.
      def dispatch_action(spec)
        component = (spec["component"] || spec["type"]).to_s
        action = spec["action"].to_s

        case component
        when "navigation", "navigate"
          navigate_screen(spec["url"], action, spec)
        when "dialog"
          show_native_dialog(spec)
        when "toast"
          show_toast(spec)
        when "sheet"
          present_sheet(spec["url"])
        when "drawer"
          show_drawer
        when "share"
          share_content(spec)
        when "clipboard", "copy"
          copy_to_clipboard(spec)
        when "launcher", "url", "url_launcher"
          launch_external_url(spec)
        when "haptic", "haptic_feedback"
          haptic_feedback(spec)
        else
          case action
          when "dialog" then show_native_dialog(spec)
          when "toast"  then show_toast(spec)
          when "sheet"  then present_sheet(spec["url"])
          when "drawer" then show_drawer
          when "end_drawer" then show_end_drawer
          when "share" then share_content(spec)
          when "copy", "clipboard" then copy_to_clipboard(spec)
          when "launch", "url", "url_launcher" then launch_external_url(spec)
          when "haptic", "haptic_feedback" then haptic_feedback(spec)
          when "back"   then pop
          when "navigate" then navigate_screen(spec["url"], spec["mode"] || "push", spec)
          when "push", "replace", "root" then navigate_screen(spec["url"], action, spec)
          end
        end
      end

      # --- Native services ---------------------------------------------------

      def share_content(spec)
        clear_transient_overlays
        files = spec["files"]
        uri = share_uri_for(spec)
        text = spec["text"] || spec["message"] || spec["content"]

        if files
          @page.share_files(files, text: text, title: spec["title"], subject: spec["subject"])
        elsif uri && text.to_s.empty?
          @page.share_uri(uri)
        else
          @page.share_text(text.to_s, title: spec["title"], subject: spec["subject"])
        end
        haptic_feedback({ "style" => "selection" }) if spec["haptic"]
      rescue StandardError
        nil
      end

      def copy_to_clipboard(spec)
        clear_transient_overlays
        value = spec["text"] || spec["value"] || spec["content"] || spec["message"] || spec["url"]
        return if value.to_s.empty?

        @page.set_clipboard(value)
        show_toast(
          "message" => spec["toast"].to_s,
          "duration" => (spec["toast_duration"] || spec["duration"] || 900).to_s
        ) unless spec["toast"].to_s.empty?
        haptic_feedback({ "style" => "selection" }) if spec.fetch("haptic", true)
      rescue StandardError
        nil
      end

      def share_uri_for(spec)
        uri = spec["uri"] || spec["url"]
        return current_url if uri.to_s.empty? || uri.to_s == "#"

        uri
      end

      def same_url?(left, right)
        absolute_url(left).to_s == absolute_url(right).to_s
      end

      def clear_transient_overlays
        @page.snackbar = nil if @page.respond_to?(:snackbar=)
      rescue StandardError
        nil
      end

      def launch_external_url(spec)
        url = spec["url"] || spec["href"] || spec["uri"]
        return if url.to_s.empty?

        @page.launch_url(url.to_s, mode: spec["mode"])
      rescue StandardError
        nil
      end

      def haptic_feedback(spec)
        style = (spec["style"] || spec["kind"] || spec["impact"] || "selection").to_s
        case style
        when "heavy" then @page.heavy_impact
        when "medium" then @page.medium_impact
        when "light" then @page.light_impact
        when "vibrate" then @page.vibrate
        else @page.selection_click
        end
      rescue StandardError
        nil
      end
    end
  end
end
