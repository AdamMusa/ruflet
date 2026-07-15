# frozen_string_literal: true

require "uri"

# Minimal CGI escaping helpers.
class CGI
  class << self
    def escape(text)
      URI.encode_www_form_component(text)
    end

    def unescape(text)
      URI.decode_www_form_component(text)
    end

    def escape_html(text)
      text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub("\"", "&quot;")
          .gsub("'", "&#39;")
    end
    alias escapeHTML escape_html

    def unescape_html(text)
      text.to_s
          .gsub("&amp;", "&")
          .gsub("&lt;", "<")
          .gsub("&gt;", ">")
          .gsub("&quot;", "\"")
          .gsub("&#39;", "'")
    end
    alias unescapeHTML unescape_html
  end
end
