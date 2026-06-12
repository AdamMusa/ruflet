# frozen_string_literal: true

require "erb"

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

      private

      def ruflet_css_dimension(value)
        value.is_a?(Numeric) ? "#{value}px" : value.to_s
      end

      def ruflet_html_safe(string)
        string.respond_to?(:html_safe) ? string.html_safe : string
      end
    end
  end
end
