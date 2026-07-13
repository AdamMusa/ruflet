# frozen_string_literal: true

# Minimal URI helpers: www-form encoding/decoding used for query strings.
module URI
  class << self
    def decode_www_form_component(value)
      text = value.to_s
      out = +""
      index = 0
      length = text.length
      while index < length
        char = text[index]
        if char == "+"
          out << " "
          index += 1
        elsif char == "%" && index + 2 < length
          out << text[index + 1, 2].to_i(16).chr
          index += 3
        else
          out << char
          index += 1
        end
      end
      out
    end

    def encode_www_form_component(value)
      text = value.to_s
      out = +""
      text.each_byte do |byte|
        if (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) ||
           (byte >= 97 && byte <= 122) || byte == 45 || byte == 46 ||
           byte == 95 || byte == 42
          out << byte.chr
        elsif byte == 32
          out << "+"
        else
          out << format("%%%02X", byte)
        end
      end
      out
    end

    def decode_www_form(str, _enc = nil)
      text = str.to_s
      return [] if text.empty?

      text.split("&").reject(&:empty?).map do |pair|
        key, value = pair.split("=", 2)
        [decode_www_form_component(key.to_s), decode_www_form_component(value.to_s)]
      end
    end

    def encode_www_form(pairs)
      pairs.map do |key, value|
        "#{encode_www_form_component(key)}=#{encode_www_form_component(value)}"
      end.join("&")
    end
  end
end
