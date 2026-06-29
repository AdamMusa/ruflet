# frozen_string_literal: true

module Ruflet
  module Rails
    class NativeApp
      private

      # --- Stack operations ---------------------------------------------------

      def push_webview(url, root: false, spec: nil)
        url = absolute_url(url)
        return if url.empty?

        screen = Screen.new(url: url)
        screen.appbar_spec = appbar_spec_from(spec)
        screen.appbar_spec ||= default_screen_appbar_spec(url) unless root
        screen.title_text = build_title_text(screen)
        screen.loading = build_loading_state
        screen.webview = build_webview(screen)
        screen.body = build_webview_body(screen)
        screen.view = root ? build_view(screen) : @screens.first&.view
        @screens.push(screen)
        root ? flush : apply_screen_to_shell(screen)
        screen
      end

      def pop
        return if @screens.size <= 1

        @screens.pop
        apply_screen_to_shell(@screens.last)
        close_drawer(@screens.last)
        sync_drawer_selection(@screens.last)
      end

      def flush
        @page.views = [@screens.last&.view].compact
        @page.update
        reconcile_loading_visibility
      end

      # --- Webview screen + native chrome ------------------------------------

      def build_webview(screen)
        webview(
          url: screen.url,
          method: "get",
          expand: true,
          enable_javascript: true,
          # The mobile client defaults JavaScriptMode to disabled and ignores the
          # enable_javascript prop, so switch JS on as each page starts loading.
          # Without it the in-page adapter cannot read ERB data-ruflet
          # declarations, and WebAuthn/passkeys will not work.
          on_page_started: lambda do |_event|
            show_loading(screen)
            enable_js(screen.webview)
          end,
          on_page_ended: lambda do |_event|
            inject_html_adapter(screen)
            hide_loading(screen)
          end,
          on_web_resource_error: ->(_event) { hide_loading(screen) },
          on_console_message: ->(event) { handle_message(screen, message_of(event)) }
        )
      end

      def build_webview_body(screen)
        return screen.webview unless screen.loading

        stack(
          [screen.webview, screen.loading],
          fit: "expand",
          expand: true
        )
      end

      def build_view(screen)
        args = { route: "/" }
        appbar = build_appbar(screen)
        args[:appbar] = appbar if appbar
        args[:drawer] = screen.drawer if screen.drawer
        args[:end_drawer] = screen.end_drawer if screen.end_drawer
        args[:navigation_bar] = @navigation_bar unless @navigation_bar.nil?
        args[:bottom_appbar] = @bottom_appbar unless @bottom_appbar.nil?
        view(screen_controls(screen), **args)
      end

      def screen_controls(screen)
        body = screen.body || screen.webview
        return [body] unless screen.rail

        [
          row(
            [screen.rail, body],
            expand: true,
            spacing: 0
          )
        ]
      end

      # Native chrome is opt-in: render an AppBar only when the app asks for one
      # (a title or actions) or the page declared one via `ruflet-appbar`
      # (screen.appbar_spec). With neither, the screen is a full-bleed webview —
      # the web page already renders its own header, so a native AppBar on top of
      # it just duplicates that chrome.
      def build_appbar(screen)
        spec = screen.appbar_spec
        actions = spec ? spec[:actions] : resolve_actions
        leading = spec ? spec[:leading] : nil
        has_title = spec ? true : !@title.to_s.strip.empty?
        return nil if !has_title && !leading && Array(actions).empty?

        args = spec ? spec[:props].dup : {}
        args[:title] = screen.title_text
        if leading
          args[:leading] = leading
          args[:automatically_imply_leading] = false
        end
        args[:actions] = actions unless Array(actions).empty?
        appbar(**args)
      end

      def build_title_text(screen)
        text(title_for(screen), **(screen.appbar_spec ? screen.appbar_spec[:title_props] : {}))
      end

      def title_for(screen)
        title = screen.appbar_spec&.fetch(:title, nil)
        title.nil? ? @title : title.to_s
      end

      def appbar_spec_from(spec)
        return nil unless spec.is_a?(Hash)

        title = spec["title"]
        leading = drawer_leading?(spec["leading"]) ? nil : build_chrome_button(spec["leading"])
        actions = Array(spec["actions"]).filter_map { |action| build_chrome_button(action) }
        props = ruflet_props_for(:appbar, spec)
        title_props = nested_ruflet_props(spec, "title_props", "title_text_props", control: :text)
        return nil if title.to_s.strip.empty? && leading.nil? && actions.empty? && props.empty?

        { title: title.to_s, leading: leading, actions: actions, props: props, title_props: title_props }
      end

      def default_screen_appbar_spec(url)
        {
          title: title_from_url(url),
          leading: build_chrome_button({ "icon" => "close", "action" => "back" }),
          actions: [],
          props: {},
          title_props: {}
        }
      end

      def title_from_url(url)
        path = URI.parse(url.to_s).path.to_s
        label = path.split("/").reject(&:empty?).last.to_s
        label = "Screen" if label.empty?
        label.tr("_-", " ").split.map(&:capitalize).join(" ")
      rescue URI::InvalidURIError
        "Screen"
      end

      def build_chrome_button(spec)
        spec = { "icon" => spec } unless spec.is_a?(Hash)
        icon = spec["icon"].to_s
        return nil if icon.empty?

        mode = (spec["action"] || spec["mode"] || "push").to_s
        url = spec["url"].to_s
        icon_button(
          icon,
          **ruflet_props_for(:icon_button, spec),
          on_click: lambda do |_event|
            if mode == "back"
              pop
            elsif mode == "drawer"
              show_drawer
            elsif mode == "end_drawer"
              show_end_drawer
            elsif mode == "menu"
              show_native_menu(spec)
            elsif !url.empty?
              navigate_screen(url, mode, spec)
            end
          end
        )
      end

      def drawer_leading?(spec)
        spec.is_a?(Hash) && %w[drawer end_drawer].include?((spec["action"] || spec["mode"]).to_s)
      end

      def resolve_actions
        @actions.respond_to?(:call) ? @actions.call : @actions
      end

      # Rebuild the mounted shell if chrome arrives before the initial view has
      # a client wire id; otherwise patch the existing shell in place.
      def rebuild_view(screen)
        if screen.equal?(@screens.first) && @screens.length == 1
          screen.view = build_view(screen)
          flush
        else
          apply_screen_to_shell(screen)
        end
      end

      def update_screen_appbar(screen)
        appbar = build_appbar(screen)
        return rebuild_view(screen) unless screen.view&.wire_id

        @page.update(screen.view, appbar: appbar)
      end

      def update_screen_drawer(screen, drawer:, end_drawer: :__ruflet_rails_unchanged)
        screen.drawer = drawer
        screen.end_drawer = end_drawer unless end_drawer == :__ruflet_rails_unchanged
        return rebuild_view(screen) unless screen.view&.wire_id

        props = { drawer: drawer }
        props[:end_drawer] = end_drawer unless end_drawer == :__ruflet_rails_unchanged
        @page.update(screen.view, **props)
      end

      def update_screen_controls(screen)
        return rebuild_view(screen) unless screen.view&.wire_id

        @page.update(screen.view, controls: screen_controls(screen))
      end

      def apply_screen_to_shell(screen)
        shell = @screens.first
        return unless screen && shell&.view

        screen.view = shell.view
        appbar = build_appbar(screen)
        props = {
          controls: screen_controls(screen),
          appbar: appbar,
          drawer: shell.drawer || screen.drawer,
          end_drawer: shell.end_drawer || screen.end_drawer,
          navigation_bar: screen.equal?(shell) ? @navigation_bar : nil,
          bottom_appbar: screen.equal?(shell) ? @bottom_appbar : nil
        }
        if shell.view.wire_id
          @page.update(shell.view, **props)
        else
          props.each { |key, value| shell.view.props[key.to_s] = value }
          flush
        end
        reconcile_loading_visibility
      end

      def update_root_navigation_bar
        root = @screens.first
        return unless root
        return rebuild_view(root) unless root.view&.wire_id

        @page.update(root.view, navigation_bar: @navigation_bar)
      end

      def build_loading_state
        return nil unless @loading
        return @loading if @loading.is_a?(Ruflet::Control)

        loading_spec = @loading.is_a?(Hash) ? ruflet_stringify_nested(@loading) : {}
        loading_type = (loading_spec["type"] || loading_spec["component"]).to_s
        if loading_type == "text"
          label = loading_spec["label"] || loading_spec["text"] || loading_spec["message"] || "Loading..."
          return build_text_loading_state(label, loading_spec)
        end

        if @loading.is_a?(String) || (@loading.respond_to?(:to_sym) && @loading.to_sym == :text)
          return build_text_loading_state(@loading.is_a?(String) ? @loading : "Loading...")
        end

        container(
          bgcolor: "#F7F8FB",
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          padding: 24,
          visible: true,
          **nested_ruflet_props(loading_spec, "container_props", control: :container),
          content: shimmer(
            base_color: "#E5E7EB",
            highlight_color: "#F8FAFC",
            **nested_ruflet_props(loading_spec, "shimmer_props", control: :shimmer),
            content: column(
              loading_bars(loading_spec),
              spacing: 18,
              expand: true
            )
          )
        )
      end

      def build_text_loading_state(label, spec = {})
        container(
          bgcolor: "#F7F8FB",
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          alignment: "center",
          visible: true,
          **nested_ruflet_props(spec, "container_props", control: :container),
          content: text(label, **nested_ruflet_props(spec, "text_props", control: :text))
        )
      end

      def loading_bars(spec = {})
        bar_props = nested_ruflet_props(spec, "bar_props", control: :container)
        [
          loading_bar(width: 190, height: 28, props: bar_props),
          loading_bar(width: 320, height: 16, props: bar_props),
          loading_bar(width: 280, height: 16, props: bar_props),
          loading_gap(14),
          loading_bar(width: 340, height: 86, props: bar_props),
          loading_bar(width: 300, height: 86, props: bar_props),
          loading_bar(width: 330, height: 86, props: bar_props)
        ]
      end

      def loading_bar(width:, height:, props: {})
        container(
          width: width,
          height: height,
          bgcolor: "#E5E7EB",
          border_radius: 10,
          **props
        )
      end

      def loading_gap(height)
        container(height: height)
      end

      def show_loading(screen)
        return unless screen&.loading
        return if screen.loading.props["visible"] == true

        screen.loading.props["visible"] = true
        @page.update(screen.loading, visible: true) if screen.loading.wire_id
      end

      def hide_loading(screen)
        return unless screen&.loading
        return if screen.loading.props["visible"] == false

        screen.loading.props["visible"] = false
        @page.update(screen.loading, visible: false) if screen.loading.wire_id
      end

      def reconcile_loading_visibility
        @screens.each do |screen|
          next unless screen.loading&.wire_id
          next unless screen.loading.props.key?("visible")

          @page.update(screen.loading, visible: screen.loading.props["visible"])
        end
      rescue StandardError
        nil
      end
    end
  end
end
