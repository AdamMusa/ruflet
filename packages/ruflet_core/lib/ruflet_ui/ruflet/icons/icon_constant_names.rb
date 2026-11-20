# frozen_string_literal: true

module Ruflet
  # Derives Ruby constant names from icon identifiers. Implemented byte-wise
  # rather than with regexps: the tables are built for thousands of icons at
  # load time, and this path must stay fast on every supported runtime.
  module IconNames
    module_function

    def constant_for(name)
      text = +""
      prev_underscore = false
      name.to_s.each_byte do |byte|
        if (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
          text << byte.chr
          prev_underscore = false
        elsif !prev_underscore
          text << "_"
          prev_underscore = true
        end
      end
      text = text[1..-1] while text.start_with?("_")
      text = text[0...-1] while text.end_with?("_")
      first = text.getbyte(0)
      text = "ICON_#{text}" if first && first >= 48 && first <= 57
      text
    end

    # What a set's constant-name index gives for key (an upcased name) when
    # key is a compiled-map key that is also its own constant name, as every
    # key but CLASS_ is; nil otherwise. The index maps each constant name to
    # its map key, so for such a key the answer needs no index. The index
    # hands back the map's own key, so the text takes that key's encoding,
    # not the caller's (a Symbol's text is US-ASCII; the keys are UTF-8).
    def own_constant_text(key, source)
      return nil unless source.key?(key) && constant_for(key) == key

      text = key.downcase
      return text unless text.respond_to?(:force_encoding)

      source.each_key { |stored| return text.force_encoding(stored.encoding) }
      text
    end
  end
end
