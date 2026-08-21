# frozen_string_literal: true

module Ruflet
  module Rails
    module HtmlDsl
      # Minimal, dependency-free HTML parser for the Ruflet HTML DSL.
      #
      # ERB output is developer-authored markup, so this parser expects
      # reasonably well-formed documents: tags are balanced (void elements
      # aside) and attribute values are quoted or simple tokens. It exists so
      # the DSL works everywhere ruflet_rails runs, including runtimes where
      # nokogiri is unavailable.
      class Parser
        VOID_ELEMENTS = %w[
          area base br col embed hr img input link meta param source track wbr
        ].freeze
        RAW_TEXT_ELEMENTS = %w[script style].freeze

        Element = Struct.new(:tag, :attrs, :children) do
          def element? = true
          def text? = false

          # Concatenated text of all descendant text nodes.
          def text
            children.map { |child| child.text? ? child.value : child.text }.join.strip
          end

          def [](name)
            attrs[name.to_s]
          end

          def key?(name)
            attrs.key?(name.to_s)
          end

          def elements
            children.select(&:element?)
          end
        end

        TextNode = Struct.new(:value) do
          def element? = false
          def text? = true
        end

        def self.parse(html)
          new(html.to_s).parse
        end

        def initialize(html)
          @html = html
          @pos = 0
          @length = html.length
        end

        # Returns the list of top-level nodes.
        def parse
          root = Element.new("#root", {}, [])
          stack = [root]

          until eos?
            text = scan_text
            stack.last.children << TextNode.new(decode_entities(text)) unless text.strip.empty?
            break if eos?

            if peek_string?("<!--")
              skip_past("-->")
            elsif peek_string?("<!") || peek_string?("<?")
              skip_past(">")
            elsif peek_string?("</")
              tag = scan_closing_tag
              close_element(stack, tag) if tag
            else
              element, self_closing = scan_opening_tag
              next unless element

              if RAW_TEXT_ELEMENTS.include?(element.tag)
                skip_raw_text(element.tag)
                next
              end

              stack.last.children << element
              stack.push(element) unless self_closing || VOID_ELEMENTS.include?(element.tag)
            end
          end

          root.children
        end

        private

        def eos?
          @pos >= @length
        end

        def peek_string?(str)
          @html[@pos, str.length] == str
        end

        def scan_text
          start = @pos
          next_tag = @html.index("<", @pos)
          @pos = next_tag || @length
          @html[start...@pos].to_s
        end

        def skip_past(marker)
          index = @html.index(marker, @pos)
          @pos = index ? index + marker.length : @length
        end

        def scan_closing_tag
          match = @html.match(/\G<\/\s*([a-zA-Z][a-zA-Z0-9:_-]*)\s*>/, @pos)
          unless match
            skip_past(">")
            return nil
          end

          @pos += match[0].length
          match[1].downcase
        end

        def scan_opening_tag
          match = @html.match(/\G<\s*([a-zA-Z][a-zA-Z0-9:_-]*)/, @pos)
          unless match
            # Stray "<" that is not a tag: emit it as text.
            @pos += 1
            return [nil, false]
          end

          @pos += match[0].length
          tag = match[1].downcase
          attrs = scan_attributes
          self_closing = false

          if peek_string?("/>")
            self_closing = true
            @pos += 2
          elsif peek_string?(">")
            @pos += 1
          else
            skip_past(">")
          end

          [Element.new(tag, attrs, []), self_closing]
        end

        ATTRIBUTE_PATTERN = /\G\s*([^\s=\/>"']+)(?:\s*=\s*("([^"]*)"|'([^']*)'|[^\s>]+))?/

        def scan_attributes
          attrs = {}
          loop do
            skip_whitespace
            break if eos? || peek_string?(">") || peek_string?("/>")

            match = @html.match(ATTRIBUTE_PATTERN, @pos)
            break unless match

            @pos += match[0].length
            name = match[1].downcase
            value = match[3] || match[4] || (match[2] ? match[2] : "")
            attrs[name] = decode_entities(value)
          end
          attrs
        end

        def skip_whitespace
          @pos += 1 while !eos? && @html[@pos] =~ /\s/
        end

        def skip_raw_text(tag)
          closing = "</#{tag}"
          index = @html.downcase.index(closing, @pos)
          if index
            @pos = index
            skip_past(">")
          else
            @pos = @length
          end
        end

        # Close the innermost open element with this tag; tolerate stray
        # closers and mildly mis-nested markup by unwinding to the match.
        def close_element(stack, tag)
          index = stack.rindex { |element| element.tag == tag }
          return unless index&.positive?

          stack.pop while stack.length > index
        end

        ENTITIES = {
          "&amp;" => "&", "&lt;" => "<", "&gt;" => ">",
          "&quot;" => '"', "&#39;" => "'", "&apos;" => "'", "&nbsp;" => " "
        }.freeze

        def decode_entities(text)
          return text unless text.include?("&")

          decoded = text
          ENTITIES.each { |entity, char| decoded = decoded.gsub(entity, char) }
          decoded.gsub(/&#(\d+);/) { Regexp.last_match(1).to_i.chr(Encoding::UTF_8) }
        rescue RangeError
          decoded
        end
      end
    end
  end
end
