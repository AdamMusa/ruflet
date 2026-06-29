# frozen_string_literal: true

module Ruflet
  module Rails
    class NativeApp
      private

      # Screen navigation modes:
      #   push    - add Ruby-side history, then patch the native shell body
      #   replace - swap the current history entry for a new body URL
      #   root    - reset history to the root shell body
      #   sheet   - present the URL as a bottom-sheet web modal
      #   back    - restore the previous history entry
      def navigate_screen(url, mode, spec = nil)
        url = absolute_url(url)
        mode = mode.to_s
        mode = "push" if mode.empty?
        if bottomnav_item_for(url) && !%w[back sheet].include?(mode)
          mode = "root"
          spec = bottomnav_appbar_spec(url, spec)
        end
        case mode
        when "back"    then pop
        when "root"    then go_webview(url, spec: spec)
        when "replace" then replace_webview(url, spec: spec)
        when "sheet"   then present_sheet(url)
        else                push_webview(url, spec: spec)
        end
      end

      # Root navigation keeps the mounted Ruflet shell (AppBar / drawer / bottom
      # chrome) alive and swaps only the WebView body.
      def go_webview(url, spec: nil)
        url = absolute_url(url)
        return if url.empty?

        root = @screens.first
        if root&.webview&.wire_id
          @screens = [root] if @screens.size > 1
          navigate_root_body(root, url, spec)
        else
          @screens.clear
          push_webview(url, root: true, spec: spec)
        end
      end

      # Swap only the mounted shell body. A fresh WebView gets fresh client-side
      # listeners while the AppBar, drawer, and bottom chrome stay mounted.
      def navigate_root_body(screen, url, spec)
        screen.url = url
        screen.webview = build_webview(screen)
        screen.loading = build_loading_state
        screen.body = build_webview_body(screen)
        apply_spec_chrome(screen, spec)
        sync_drawer_selection(screen)
        update_screen_controls(screen)
        sync_root_navigation_bar_selection
      end

      # Apply declared chrome onto the reused shell in place. A title-only hint
      # just repaints the AppBar text; richer chrome replaces the AppBar control.
      def apply_spec_chrome(screen, spec)
        new_spec = appbar_spec_from(spec)
        return unless new_spec

        if new_spec[:leading].nil? && Array(new_spec[:actions]).empty?
          update_screen_title(screen, new_spec[:title].to_s)
          return
        end

        screen.appbar_spec = new_spec
        screen.appbar_signature = nil
        screen.title_text = text(title_for(screen))
        update_screen_appbar(screen)
      end

      # Repaint just the AppBar's title text in place (no AppBar rebuild).
      def update_screen_title(screen, title)
        return if title.empty?

        text = screen.title_text
        return unless text

        if text.wire_id
          return if text.props["value"] == title

          @page.update(text, value: title)
        else
          text.props["value"] = title
        end
      end

      # Replace the current top screen with a new one (no extra back step).
      def replace_webview(url, spec: nil)
        url = absolute_url(url)
        return if url.empty?

        root = @screens.size <= 1
        @screens.pop unless @screens.empty?
        push_webview(url, root: root, spec: spec)
      end

      # --- HTML-declared native chrome ---------------------------------------

      # The page declared a `ruflet-appbar`: give the reporting screen a native
      # AppBar with that title and any action buttons (each navigates on tap).
      def apply_appbar(screen, spec)
        return unless screen

        spec = bottomnav_appbar_spec(screen.url, spec) if screen.equal?(@screens.first) && bottomnav_item_for(screen.url)
        remember_appbar_spec(screen.url, spec)
        signature = JSON.generate(canonicalize(spec))
        return if screen.appbar_signature == signature

        title = spec["title"].to_s
        screen.title_text = text(title)
        leading = drawer_leading?(spec["leading"]) ? nil : build_chrome_button(spec["leading"])
        actions = Array(spec["actions"]).filter_map { |action| build_chrome_button(action) }
        screen.appbar_spec = { title: title, leading: leading, actions: actions }
        screen.appbar_signature = signature
        update_screen_appbar(screen)
      end

      # The page declared a `ruflet-bottomnav`: build a native NavigationBar on
      # the root view. Selecting a destination switches to that URL as a fresh
      # root (tab semantics).
      def apply_bottomnav(spec)
        @bottomnav_spec = spec
        return unless buildable_bottomnav?(spec)

        # Like the drawer, the bottom bar is a persistent client-owned control:
        # the signature ignores selection, so re-reporting it on each page load
        # only re-points the selected tab instead of rebuilding (and churning)
        # the control.
        signature = structural_signature(spec)
        if @bottomnav_signature == signature
          sync_root_navigation_bar_selection
          return
        end

        @navigation_bar = build_bottomnav(spec)
        @bottomnav_signature = signature
        update_root_navigation_bar
      end

      # The page declared a `ruflet-drawer`: build a native NavigationDrawer on
      # the reporting screen. Selecting a destination closes the drawer first,
      # then applies that item's requested navigation mode.
      def apply_drawer(screen, spec)
        return unless screen

        @drawer_spec = spec
        items = Array(spec["items"])
        urls = items.map { |item| absolute_url(item["url"]) }
        modes = items.map { |item| (item["action"] || item["mode"] || "root").to_s }
        selected_index = drawer_selected_index(items)
        destinations = items.each_with_index.filter_map do |item, index|
          build_drawer_destination(item, selected: index == selected_index, on_click: lambda do |_event|
            select_drawer_item(screen, items, urls, modes, index)
          end)
        end
        return if destinations.empty?

        # The drawer is a persistent, client-owned control. Each page re-reports it
        # on load; when the structure is unchanged we keep the same control and
        # only re-point its selection, so its open/close state survives navigation.
        signature = structural_signature(spec)
        if screen.drawer_signature == signature
          sync_drawer_selection(screen)
          if @drawer_open_requested
            @drawer_open_requested = false
            show_drawer
          end
          return
        end

        drawer = navigation_drawer(
          destinations,
          selected_index: selected_index,
          on_change: lambda do |event|
            index = navigation_index(event)
            select_drawer_item(screen, items, urls, modes, index)
          end
        )
        screen.drawer_signature = signature
        update_screen_drawer(screen, drawer: drawer)
        if @drawer_open_requested
          @drawer_open_requested = false
          show_drawer
        end
      end

      # The page declared a `ruflet-rail`: desktop/tablet native navigation.
      # Unlike drawer/bottom nav, NavigationRail is a control, so the WebView
      # body is wrapped in a Row with the rail on the left.
      def apply_rail(screen, spec)
        return unless screen

        items = Array(spec["items"])
        destinations = items.filter_map { |item| build_rail_destination(item) }
        return if destinations.length < 2

        urls = items.map { |item| absolute_url(item["url"]) }

        # Persistent client-owned control: same structure → only re-point the
        # selection, never rebuild.
        signature = structural_signature(spec)
        if screen.rail_signature == signature
          sync_rail_selection(screen, urls)
          return
        end

        modes = items.map { |item| (item["action"] || item["mode"] || "root").to_s }
        rail_args = {
          destinations: destinations,
          selected_index: items.index { |item| item["selected"] } || 0,
          label_type: spec["label_type"] || spec["labelType"] || "all",
          on_change: lambda do |event|
            index = navigation_index(event)
            target = urls[index].to_s
            next if target.empty?

            mode = modes[index]
            spec = mode == "root" ? { "title" => items[index]["label"].to_s } : nil
            navigate_screen(target, mode, spec)
          end
        }
        rail_args[:extended] = !!spec["extended"] unless spec["extended"].nil?
        rail_args[:min_width] = spec["min_width"].to_i if spec["min_width"]
        rail_args[:min_extended_width] = spec["min_extended_width"].to_i if spec["min_extended_width"]
        screen.rail = navigation_rail(**rail_args)
        screen.rail_signature = signature
        update_screen_controls(screen)
      end

      # Signature of a chrome spec's STRUCTURE, ignoring which item is currently
      # selected. Selection is client-owned state we patch via `selected_index`,
      # so a navigation that only moves the highlight keeps the same controls.
      def structural_signature(spec)
        JSON.generate(canonicalize(strip_selection(spec)))
      end

      def strip_selection(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), out|
            next if %w[selected selected_index].include?(key.to_s)

            out[key] = strip_selection(nested)
          end
        when Array
          value.map { |item| strip_selection(item) }
        else
          value
        end
      end

      def canonicalize(value)
        case value
        when Hash
          value.keys.map(&:to_s).sort.each_with_object({}) do |key, out|
            original_key = value.key?(key) ? key : key.to_sym
            out[key] = canonicalize(value[original_key])
          end
        when Array
          value.map { |item| canonicalize(item) }
        else
          value
        end
      end

      def build_destination(item)
        icon = item["icon"].to_s
        return nil if icon.empty?

        navigation_bar_destination(icon: icon, label: item["label"].to_s)
      end

      def buildable_bottomnav?(spec)
        Array(spec["items"]).filter_map { |item| build_destination(item) }.length >= 2
      end

      def build_bottomnav(spec)
        items = Array(spec["items"])
        destinations = items.filter_map { |item| build_destination(item) }
        urls = items.map { |item| absolute_url(item["url"]) }

        navigation_bar(
          destinations: destinations,
          selected_index: bottomnav_selected_index(items),
          on_change: lambda do |event|
            index = navigation_index(event)
            target = urls[index].to_s
            next if target.empty? || same_url?(target, current_url)

            # Carry the tab's label so the AppBar shows the destination's name
            # immediately, unless the destination page already declared a more
            # specific native AppBar (e.g. Home tab label -> Demo app title).
            go_webview(target, spec: bottomnav_appbar_spec(target, { "title" => items[index]["label"].to_s }))
          end
        )
      end

      def bottomnav_selected_index(items)
        urls = items.map { |item| absolute_url(item["url"]) }
        urls.index { |candidate| same_url?(candidate, current_url) } ||
          items.index { |item| item["selected"] } || 0
      end

      def bottomnav_appbar_spec(url, spec)
        declared = appbar_spec_for_url(url)
        label = bottomnav_item_for(url)&.fetch("label", nil).to_s
        title =
          if declared && !declared["title"].to_s.empty?
            declared["title"].to_s
          elsif spec.is_a?(Hash) && !spec["title"].to_s.empty?
            spec["title"].to_s
          else
            label
          end
        actions = declared ? declared["actions"] : (spec.is_a?(Hash) ? spec["actions"] : nil)
        { "title" => title, "leading" => { "action" => "drawer" }, "actions" => actions }.compact
      end

      def bottomnav_item_for(url)
        items = Array(@bottomnav_spec && @bottomnav_spec["items"])
        items.find { |item| same_url?(absolute_url(item["url"]), url) }
      end

      def remember_appbar_spec(url, spec)
        return unless spec.is_a?(Hash)

        key = appbar_spec_key(url)
        @appbar_specs_by_url[key] = canonicalize(spec) if key
      end

      def appbar_spec_for_url(url)
        key = appbar_spec_key(url)
        key && @appbar_specs_by_url[key]
      end

      def appbar_spec_key(url)
        uri = URI.parse(absolute_url(url))
        path = uri.path.to_s.empty? ? "/" : uri.path.to_s
        "#{uri.scheme}://#{uri.host}:#{uri.port}#{path}"
      rescue URI::InvalidURIError
        nil
      end

      def sync_root_navigation_bar_selection
        return unless @navigation_bar&.wire_id && @bottomnav_spec

        index = bottomnav_selected_index(Array(@bottomnav_spec["items"]))
        return if @navigation_bar.props["selected_index"] == index

        @navigation_bar.props["selected_index"] = index
        @page.update(@navigation_bar, selected_index: index)
      end

      def build_drawer_destination(item, selected: false, on_click: nil)
        icon = item["icon"].to_s
        return nil if icon.empty?

        list_tile(
          leading: icon(icon),
          title: text(item["label"].to_s),
          selected: selected,
          on_click: on_click
        )
      end

      def select_drawer_item(screen, items, urls, modes, index)
        close_drawer(screen)
        target = urls[index].to_s
        return if target.empty?

        if same_url?(target, current_url)
          sync_drawer_selection(screen)
          return
        end

        mode = modes[index]
        # Only a tab (root) switch carries a title hint to repaint the AppBar
        # title in place. A push keeps its own declared chrome (notably the
        # back button), so we must NOT force a title-only AppBar on it.
        spec = mode == "root" ? { "title" => items[index]["label"].to_s } : nil
        navigate_screen(target, mode, spec)
        close_drawer(@screens.last)
        sync_drawer_selection(screen)
      end

      def build_rail_destination(item)
        icon = item["icon"].to_s
        return nil if icon.empty?

        navigation_rail_destination(icon: icon, label: item["label"].to_s)
      end

      def navigation_index(event)
        data = event.respond_to?(:data) ? event.data : event
        return (data["selected_index"] || data["value"] || data["i"] || 0).to_i if data.is_a?(Hash)

        data.to_i
      end

      # Keep the drawer's highlighted destination in sync with the route we are
      # actually on. Selecting a drawer item (or tapping a tab) leaves the drawer
      # marking that item, and the screen's WebView is not re-reported on a tab
      # switch or a back navigation — so without this the drawer keeps
      # highlighting a route we already left. Re-point the selection to the item
      # matching the current URL (or the declared default). Called after every
      # root navigation and on back.
      def sync_drawer_selection(screen)
        drawer = screen&.drawer
        return unless drawer&.wire_id

        index = drawer_selected_index(Array(@drawer_spec && @drawer_spec["items"]))
        if drawer.props["selected_index"] != index
          drawer.props["selected_index"] = index
          @page.update(drawer, selected_index: index)
        end
        sync_drawer_tile_selection(drawer, index)
      end

      def sync_drawer_tile_selection(drawer, selected_index)
        drawer.children.each_with_index do |control, index|
          next unless control.respond_to?(:props)

          selected = index == selected_index
          next if control.props["selected"] == selected

          control.props["selected"] = selected
          @page.update(control, selected: selected) if control.wire_id
        end
      end

      def sync_rail_selection(screen, urls)
        rail = screen&.rail
        return unless rail&.wire_id

        index = urls.index { |candidate| same_url?(candidate, screen.url) } || 0
        return if rail.props["selected_index"] == index

        rail.props["selected_index"] = index
        @page.update(rail, selected_index: index)
      end

      def drawer_selected_index(items)
        urls = items.map { |item| absolute_url(item["url"]) }
        urls.index { |candidate| same_url?(candidate, current_url) } ||
          items.index { |item| item["selected"] } || 0
      end

      def show_drawer
        screen = @screens.last
        return unless screen&.view&.wire_id
        unless screen.drawer || screen.view.props["drawer"]
          if @drawer_spec
            @drawer_open_requested = true
            apply_drawer(screen, @drawer_spec)
            return
          end
          @drawer_open_requested = true
          return
        end

        invoke_drawer_when_ready(screen, "show_drawer")
      rescue StandardError
        nil
      end

      # Close the native drawer on the view that owns it (and the current top
      # screen, if different). The drawer is a persistent, client-owned control,
      # so a single ordered invoke is enough — no rebuild races it anymore.
      def close_drawer(screen = nil)
        @drawer_open_requested = false
        targets = [screen, @screens.last].compact.uniq
        targets.each { |target| invoke_close_drawer(target) }
      rescue StandardError
        nil
      end

      def show_end_drawer
        screen = @screens.last
        return unless screen&.view&.wire_id

        invoke_drawer_when_ready(screen, "show_end_drawer")
      rescue StandardError
        nil
      end

      # The drawer is a persistent control mounted on the View well before the
      # user can open it, so a single ordered invoke opens it. (The previous
      # sleep/retry loop relied on real background threads; on the embedded
      # runtime Thread runs inline, so it only blocked the UI without deferring.)
      def invoke_drawer_when_ready(screen, method_name)
        return unless screen&.view&.wire_id

        @page.invoke(screen.view, method_name)
      end

      def invoke_close_drawer(screen)
        return unless screen&.view&.wire_id

        @page.invoke(screen.view, "close_drawer")
      end

      def absolute_url(url)
        url = url.to_s
        return "" if url.empty?
        return url if URI.parse(url).absolute?

        URI.join(current_url, url).to_s
      rescue URI::InvalidURIError
        url
      end

      def current_url
        @screens.last&.url || @start_url
      end

      def message_of(event)
        data = event.respond_to?(:data) ? event.data : event
        return data["message"] || data[:message] if data.is_a?(Hash)

        data
      end
    end
  end
end
