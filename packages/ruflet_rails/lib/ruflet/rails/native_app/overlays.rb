# frozen_string_literal: true

module Ruflet
  module Rails
    class NativeApp
      private

      # --- Native dialog / toast ---------------------------------------------

      # `ruflet-action="dialog"`: open a native AlertDialog. A confirm button
      # (when given) navigates; OK just dismisses.
      def show_native_dialog(spec)
        title = spec["title"].to_s
        content = spec["content"].to_s
        actions = []

        confirm = spec["confirm"].to_s
        unless confirm.empty?
          url = spec["url"].to_s
          mode = (spec["action"] || spec["mode"] || "push").to_s
          actions << text_button(
            confirm,
            on_click: lambda do |_event|
              close_dialog
              navigate_screen(url, mode) unless url.empty?
            end
          )
        end
        actions << text_button("OK", on_click: ->(_event) { close_dialog })

        args = { actions: actions, open: true, adaptive: adaptive?(spec), on_dismiss: ->(_event) { @dialog = nil } }
        args[:title] = text(title) unless title.empty?
        args[:content] = text(content) unless content.empty?
        @dialog = alert_dialog(**args)
        @page.show_dialog(@dialog)
      end

      def close_dialog
        return unless @dialog

        @page.update(@dialog, open: false)
        @dialog = nil
      end

      # `ruflet-action="toast"`: show a native SnackBar.
      def show_toast(spec)
        message = spec["message"].to_s
        return if message.empty?

        args = { content: text(message), open: true,
                 adaptive: adaptive?(spec) }
        duration = spec["duration"].to_s
        args[:duration] = duration.to_i if duration =~ /\A\d+\z/
        @page.snackbar = snack_bar(**args)
      end

      # --- Bottom-sheet modal (web content) ----------------------------------

      SHEET_PADDING      = 20   # inset the page from the sheet edges (top clears the handle)
      SHEET_HEIGHT_RATIO = 0.82 # short enough to leave a clear peek of the screen

      # `ruflet-action="sheet"`: present a URL as a bottom-sheet modal. It must
      # READ as a modal — a sheet that slides up over the current screen with a
      # drag handle, rounded top, and a clear peek of the page behind it, not a
      # fullscreen container indistinguishable from a pushed page. The webview has
      # no intrinsic size, so the card is explicitly sized to leave that peek; the
      # uniform padding then insets the page (the top inset clears the handle).
      def present_sheet(url)
        url = absolute_url(url)
        return if url.empty?

        sheet_webview = nil
        sheet_webview = webview(
          url: url, method: "get", enable_javascript: true,
          on_page_started: ->(_event) { enable_js(sheet_webview) }
        )
        card = container(
          content: sheet_webview,
          width: sheet_card_width,
          height: sheet_card_height,
          padding: SHEET_PADDING
        )
        @sheet = bottomsheet(
          card,
          open: true,
          adaptive: true,
          dismissible: true,        # tap the peek above the sheet to dismiss
          draggable: true,          # ...or drag the handle down to dismiss
          scrollable: true,         # isScrollControlled: let the sheet grow tall
          show_drag_handle: true,   # the grab handle that signals "modal"
          use_safe_area: true,
          on_dismiss: ->(_event) { @sheet = nil }
        )
        @page.bottom_sheet = @sheet
        @page.update
      end

      # Card dimensions from the live viewport (the client reports it via the
      # resize event). Full width; height leaves a clear peek of the screen above
      # the sheet. Falls back to sensible phone dimensions before the first
      # resize report.
      def sheet_card_width
        numeric_or(@page.respond_to?(:width) ? @page.width : nil, 430.0).round
      end

      def sheet_card_height
        viewport = numeric_or(@page.respond_to?(:height) ? @page.height : nil, 800.0)
        (viewport * SHEET_HEIGHT_RATIO).round
      end

      def numeric_or(value, fallback)
        value.is_a?(Numeric) && value.positive? ? value.to_f : fallback
      end

      def adaptive?(spec)
        return false if spec.is_a?(Hash) && spec["adaptive"] == false

        true
      end
    end
  end
end
