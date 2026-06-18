# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # CodeEditor control — parity with Flet's CodeEditor extension
        # (https://flet.dev/docs/controls/codeeditor/).
        #
        # Properties: value, language, code_theme, text_style, padding, selection,
        #   gutter_style, autocomplete, autocomplete_words, issues, read_only,
        #   autofocus, plus the usual layout props.
        # Events: on_change, on_selection_change, on_focus, on_blur.
        # Methods (invoked over the wire on a mounted control): focus, fold_at,
        #   fold_comment_at_line_zero, fold_imports.
        #
        # `language` accepts a highlight.js identifier (e.g. "python", "ruby",
        # "javascript"); `code_theme` accepts a highlight.js theme name shared
        # with Markdown (e.g. "atom-one-light", "atom-one-dark", "monokai-sublime").
        class CodeEditorControl < Ruflet::Control
          TYPE = "CodeEditor".freeze
          WIRE = "CodeEditor".freeze

          def initialize(id: nil, adaptive: nil, autocomplete: nil, autocomplete_words: nil,
                         autofocus: nil, badge: nil, code_theme: nil, col: nil, data: nil,
                         disabled: nil, expand: nil, expand_loose: nil, gutter_style: nil,
                         height: nil, issues: nil, key: nil, language: nil, opacity: nil,
                         padding: nil, read_only: nil, rtl: nil, selection: nil,
                         text_style: nil, tooltip: nil, value: nil, visible: nil, width: nil,
                         on_blur: nil, on_change: nil, on_focus: nil, on_selection_change: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:autocomplete] = autocomplete unless autocomplete.nil?
            props[:autocomplete_words] = autocomplete_words unless autocomplete_words.nil?
            props[:autofocus] = autofocus unless autofocus.nil?
            props[:badge] = badge unless badge.nil?
            props[:code_theme] = code_theme unless code_theme.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:gutter_style] = gutter_style unless gutter_style.nil?
            props[:height] = height unless height.nil?
            props[:issues] = issues unless issues.nil?
            props[:key] = key unless key.nil?
            props[:language] = language unless language.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:read_only] = read_only unless read_only.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:selection] = selection unless selection.nil?
            props[:text_style] = text_style unless text_style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_selection_change] = on_selection_change unless on_selection_change.nil?
            super(type: TYPE, id: id, **props)
          end

          # Request focus for the editor.
          def focus = invoke_editor_method("focus")

          # Fold the code block that starts at the given line number.
          def fold_at(line_number)
            invoke_editor_method("fold_at", { "line_number" => line_number.to_i })
          end

          # Fold the comment block at line 0 (e.g. a license header).
          def fold_comment_at_line_zero = invoke_editor_method("fold_comment_at_line_zero")

          # Fold all import sections.
          def fold_imports = invoke_editor_method("fold_imports")

          private

          def invoke_editor_method(name, args = nil, timeout: 10, on_result: nil)
            page = runtime_page
            unless page && wire_id
              raise "CodeEditor ##{id} is not mounted yet — add it to the page before calling #{name}."
            end

            page.invoke(self, name, args: args, timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
