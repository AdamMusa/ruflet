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
  end
end
