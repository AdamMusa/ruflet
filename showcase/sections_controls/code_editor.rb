# frozen_string_literal: true

module Showcase
  module SectionsControls
    SAMPLE_CODE = <<~RUBY
      # A tiny Ruflet app
      class App < Ruflet::App
        def view(page)
          page.add(text(value: "Hello from Ruflet!"))
        end
      end
    RUBY

    def build_code_editor(page, status)
      editor = code_editor(
        SAMPLE_CODE,
        language: "ruby",
        code_theme: theme_mode == "dark" ? "atom-one-dark" : "atom-one-light",
        read_only: false,
        expand: true,
        on_change: ->(e) { page.update(status, value: "#{e.data.to_s.length} characters") },
        on_focus: ->(_e) { page.update(status, value: "Editor focused") },
        on_blur: ->(_e) { page.update(status, value: "Editor blurred") }
      )

      read_only = false

      column(
        expand: true,
        spacing: 12,
        children: [
          status,
          row(
            spacing: 8,
            children: [
              elevated_button(
                content: text(value: "Toggle read-only"),
                on_click: ->(_e) {
                  read_only = !read_only
                  page.update(editor, read_only: read_only)
                  page.update(status, value: read_only ? "Read-only" : "Editable")
                }
              ),
              elevated_button(
                content: text(value: "Focus"),
                on_click: ->(_e) { editor.focus }
              )
            ]
          ),
          container(
            expand: true,
            border_radius: 12,
            bgcolor: color_panel(page),
            content: editor
          )
        ]
      )
    end
  end
end
