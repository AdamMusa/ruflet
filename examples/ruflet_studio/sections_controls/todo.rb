# frozen_string_literal: true

module RufletStudio
  module SectionsControls
    def build_todo(page, _status)
      todos = [
        { text: "Buy milk", done: false },
        { text: "Write docs", done: true }
      ]

      input_text = ""
      input = page.text_field(
        hint_text: "What needs to be done?",
        on_change: ->(e) { input_text = e.data.to_s }
      )
      list = page.column(spacing: 6, controls: [])

      render_list = lambda do
        new_controls = todos.each_with_index.map do |item, idx|
          checkbox = page.checkbox(
            label: item[:text],
            value: item[:done],
            on_change: ->(e) {
              val = read_number(e.data, "value")
              if val.nil?
                payload = e.data.to_s
                val = payload == "true" || payload == "1"
              end
              todos[idx][:done] = val == 1 || val == true
              render_list.call
            }
          )

          page.row(
            alignment: "spaceBetween",
            controls: [
              checkbox,
              page.icon_button(
                icon: "delete",
                tooltip: "Delete",
                on_click: ->(_e) {
                  todos.delete_at(idx)
                  render_list.call
                }
              )
            ]
          )
        end

        list.children.replace(new_controls)
        page.update
      end

      add_todo = lambda do
        text = input_text.to_s.strip
        return if text.empty?

        todos << { text: text, done: false }
        page.update(input, value: "")
        render_list.call
      end

      render_list.call

      page.column(
        spacing: 8,
        controls: [
          page.text(value: "Todos", size: 20, weight: "w600", color: "#e7e9ec"),
          input,
          page.button(text: "Add", on_click: ->(_e) { add_todo.call }),
          list,
          page.control(
            :outlined_button,
            content: "Clear completed",
            on_click: ->(_e) {
              todos.reject! { |item| item[:done] }
              render_list.call
            }
          )
        ]
      )
    end
  end
end
