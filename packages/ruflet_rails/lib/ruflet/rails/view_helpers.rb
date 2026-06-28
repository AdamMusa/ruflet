# frozen_string_literal: true

require "erb"
require "json"

module Ruflet
  module Rails
    # ERB view helpers for dropping a Ruflet native UI into a server-rendered
    # Rails page. Auto-included into ActionView (see Railtie), so they are
    # available in any .erb template.
    #
    # A Ruflet web frontend is a Flutter app mounted at a route (see
    # Ruflet::Rails.web_app in config/routes.rb). To embed that native UI inside
    # an HTML page, render it in an isolated frame pointed at the mount:
    #
    #   <%= ruflet_frame "/products", height: 640 %>
    #   <%= ruflet_frame "/showcase", height: "80vh", width: "100%" %>
    #
    # The frame is same-origin by default (a relative path), so the Ruflet
    # WebSocket and assets resolve against this host with no extra config. Pass a
    # full URL to embed a Ruflet app on another host.
    module ViewHelpers
      # Embed a mounted Ruflet route as an isolated, responsive frame.
      #
      # path    - the Ruflet mount route ("/products") or a full URL.
      # height  - CSS height; a number is treated as pixels (default 600).
      # width   - CSS width; a number is treated as pixels (default "100%").
      # title   - iframe title for accessibility (default "Ruflet").
      # style   - extra CSS appended to the frame's inline style.
      # attrs   - any other iframe attributes (underscores become dashes).
      def ruflet_frame(path, height: 600, width: "100%", title: "Ruflet", style: nil, **attrs)
        base_style = "border:0;width:#{ruflet_css_dimension(width)};height:#{ruflet_css_dimension(height)};"

        attributes = {
          "src" => path.to_s,
          "title" => title.to_s,
          "loading" => "lazy",
          "style" => [base_style, style].compact.join(" ").strip
        }
        attrs.each { |key, value| attributes[key.to_s.tr("_", "-")] = value }

        markup = +"<iframe"
        attributes.each { |key, value| markup << %( #{key}="#{ERB::Util.html_escape(value)}") }
        markup << "></iframe>"
        ruflet_html_safe(markup)
      end

      # --- Native bridge annotations -----------------------------------------
      #
      # These emit plain HTML decorated with `ruflet-*` attributes. In a normal
      # browser they render and behave as ordinary HTML; inside the Ruflet
      # native shell (Ruflet::Rails.native_app) the injected bridge reads the
      # attributes and drives native navigation/chrome instead. They degrade
      # gracefully — no JavaScript required for the web rendering.

      # A header the native shell hides and re-renders as a native AppBar. Place
      # action items inside with `ruflet-icon` (use ruflet_appbar_action).
      #
      #   <%= ruflet_appbar "Inbox" do %>
      #     <%= ruflet_appbar_action "search", search_path %>
      #   <% end %>
      def ruflet_appbar(title = nil, payload: {}, leading: nil, actions: nil, **attrs, &block)
        appbar_payload = ruflet_stringify_keys(payload)
        appbar_payload["leading"] = ruflet_stringify_keys(leading) unless leading.nil?
        appbar_payload["actions"] = ruflet_stringify_keys(actions) unless actions.nil?
        data = { "data-ruflet-appbar" => appbar_payload.empty? ? "" : ruflet_json(appbar_payload),
                 "data-ruflet-title" => title,
                 "hidden" => true }
        ruflet_build_tag("header", ruflet_capture(&block), data.merge(ruflet_dash_attrs(attrs)))
      end

      # An AppBar action button (icon taps navigate).
      def ruflet_appbar_action(icon, href = nil, nav: :push, payload: {}, **attrs)
        payload = ruflet_compact_hash({ "icon" => icon, "action" => nav.to_s }.merge(ruflet_stringify_keys(payload)))
        data = { "data-ruflet-icon" => ruflet_json(payload), "href" => href }
        ruflet_build_tag("a", "", data.merge(ruflet_dash_attrs(attrs)))
      end

      # A nav the native shell hides and re-renders as a native bottom
      # NavigationBar. Items are `ruflet_nav_item` links.
      #
      #   <%= ruflet_bottom_nav do %>
      #     <%= ruflet_nav_item "Home", root_path, icon: "house", selected: true %>
      #     <%= ruflet_nav_item "Profile", profile_path, icon: "person" %>
      #   <% end %>
      def ruflet_bottom_nav(name: "bottom-navigation", **attrs, &block)
        ruflet_build_tag("nav", ruflet_capture(&block), {
          "data-ruflet-tabs" => name,
          "hidden" => true
        }.merge(ruflet_dash_attrs(attrs)))
      end

      # A destination inside ruflet_bottom_nav.
      def ruflet_nav_item(label, href, icon:, selected: false, color: nil, size: 24, **attrs)
        data = {
          "href" => href,
          "data-ruflet-icon" => ruflet_json(ruflet_compact_hash(icon: icon, label: label, color: color, size: size))
        }
        data["data-ruflet-selected"] = "true" if selected
        ruflet_build_tag("a", label, data.merge(ruflet_dash_attrs(attrs)))
      end

      # A drawer the native shell hides and re-renders as a native
      # NavigationDrawer. Items are `ruflet_drawer_item` links.
      #
      #   <%= ruflet_drawer do %>
      #     <%= ruflet_drawer_item "Home", root_path, icon: "home" %>
      #     <%= ruflet_drawer_item "Settings", settings_path, icon: "settings", nav: :push %>
      #   <% end %>
      def ruflet_drawer(action: :root, **attrs, &block)
        ruflet_build_tag("nav", ruflet_capture(&block), {
          "data-ruflet-drawer" => ruflet_json(ruflet_compact_hash(action: action.to_s)),
          "hidden" => true
        }.merge(ruflet_dash_attrs(attrs)))
      end

      # A destination inside ruflet_drawer.
      def ruflet_drawer_item(label, href, icon:, selected: false, nav: nil, **attrs)
        data = {
          "href" => href,
          "data-ruflet-icon" => ruflet_json(ruflet_compact_hash(icon: icon, label: label, action: nav&.to_s))
        }
        data["data-ruflet-selected"] = "true" if selected
        ruflet_build_tag("a", label, data.merge(ruflet_dash_attrs(attrs)))
      end

      # Desktop/tablet navigation the native shell hides and re-renders as a
      # native NavigationRail beside the WebView body.
      #
      #   <%= ruflet_navigation_rail extended: true do %>
      #     <%= ruflet_rail_item "Home", root_path, icon: "home" %>
      #     <%= ruflet_rail_item "Inbox", inbox_path, icon: "mail" %>
      #   <% end %>
      def ruflet_navigation_rail(action: :root, extended: nil, label_type: nil, breakpoint: nil, **attrs, &block)
        payload = ruflet_compact_hash(action: action.to_s, extended: extended, label_type: label_type,
                                      breakpoint: breakpoint)
        ruflet_build_tag("nav", ruflet_capture(&block), {
          "data-ruflet-rail" => ruflet_json(payload),
          "hidden" => true
        }.merge(ruflet_dash_attrs(attrs)))
      end

      alias ruflet_rail ruflet_navigation_rail

      # A destination inside ruflet_navigation_rail.
      def ruflet_rail_item(label, href, icon:, selected: false, nav: nil, **attrs)
        data = {
          "href" => href,
          "data-ruflet-icon" => ruflet_json(ruflet_compact_hash(icon: icon, label: label, action: nav&.to_s))
        }
        data["data-ruflet-selected"] = "true" if selected
        ruflet_build_tag("a", label, data.merge(ruflet_dash_attrs(attrs)))
      end

      # Native platform services from ERB. These are normal HTML elements in a
      # browser and native service calls inside Ruflet::Rails.native_app.
      def ruflet_share_link(label, href = "#", text: nil, title: nil, subject: nil, url: nil, files: nil, **attrs)
        payload = ruflet_compact_hash(component: "share", text: text, title: title, subject: subject,
                                      url: url || href, files: files)
        ruflet_action_tag("a", label, payload, { "href" => href }.merge(ruflet_dash_attrs(attrs)))
      end

      def ruflet_copy_button(label, text:, toast: "Copied", haptic: true, **attrs)
        payload = ruflet_compact_hash(component: "clipboard", text: text, toast: toast, haptic: haptic)
        ruflet_action_tag("button", label, payload, { "type" => "button" }.merge(ruflet_dash_attrs(attrs)))
      end

      def ruflet_launch_link(label, href, mode: nil, **attrs)
        payload = ruflet_compact_hash(component: "url_launcher", url: href, mode: mode)
        ruflet_action_tag("a", label, payload, { "href" => href }.merge(ruflet_dash_attrs(attrs)))
      end

      def ruflet_haptic_button(label, style: "selection", **attrs)
        payload = ruflet_compact_hash(component: "haptic", style: style)
        ruflet_action_tag("button", label, payload, { "type" => "button" }.merge(ruflet_dash_attrs(attrs)))
      end

      private

      def ruflet_action_tag(name, content, payload, attrs)
        attrs["data-ruflet-action"] = ruflet_json(ruflet_stringify_keys(payload))
        ruflet_build_tag(name, content, attrs)
      end

      # Capture block content via ActionView when available (real ERB), else
      # fall back to the block's return value (standalone use / tests).
      def ruflet_capture(&block)
        return nil unless block

        respond_to?(:capture) ? capture(&block) : block.call
      end

      # Build a tag from a name, inner content, and an attribute hash. nil/false
      # attribute values are dropped; "" is kept (a bare boolean attribute).
      def ruflet_build_tag(name, content, attributes)
        markup = +"<#{name}"
        attributes.each do |key, value|
          next if value.nil? || value == false

          markup << %( #{key}="#{ERB::Util.html_escape(value)}")
        end
        markup << ">"
        markup << content.to_s if content
        markup << "</#{name}>"
        ruflet_html_safe(markup)
      end

      # Turn extra helper kwargs (data_role:) into dashed attribute keys
      # (data-role), mirroring ruflet_frame.
      def ruflet_dash_attrs(attrs)
        attrs.each_with_object({}) do |(key, value), out|
          if value.is_a?(Hash)
            value.each do |nested_key, nested_value|
              out["#{key}-#{nested_key}".to_s.tr("_", "-")] = nested_value.nil? ? nil : nested_value.to_s
            end
          else
            out[key.to_s.tr("_", "-")] = value
          end
        end
      end

      def ruflet_compact_hash(hash)
        hash.each_with_object({}) do |(key, value), out|
          next if value.nil?

          out[key] = value
        end
      end

      def ruflet_stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), out|
            out[key.to_s] = ruflet_stringify_keys(nested)
          end
        when Array
          value.map { |nested| ruflet_stringify_keys(nested) }
        else
          value
        end
      end

      def ruflet_json(value)
        JSON.generate(value)
      end

      def ruflet_css_dimension(value)
        value.is_a?(Numeric) ? "#{value}px" : value.to_s
      end

      def ruflet_html_safe(string)
        string.respond_to?(:html_safe) ? string.html_safe : string
      end
    end
  end
end
