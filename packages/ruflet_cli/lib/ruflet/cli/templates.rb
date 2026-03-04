# frozen_string_literal: true

module Ruflet
  module CLI
    MAIN_TEMPLATE = <<~RUBY
      require "ruflet"

      class MainApp < Ruflet::App
        def initialize
          super
          @count = 0
        end

        def view(page)
          page.title = "Counter Demo"
          page.vertical_alignment = Ruflet::MainAxisAlignment::CENTER
          page.horizontal_alignment = Ruflet::CrossAxisAlignment::CENTER
          count_text = text(value: @count.to_s, size: 40)

          page.add(
            container(
              expand: true,
              padding: 24,
              content: column(
                expand: true,
                alignment: Ruflet::MainAxisAlignment::CENTER,
                horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
                spacing: 12,
                controls: [
                  text(value: "You have pushed the button this many times:"),
                  count_text
                ]
              )
            ),
            appbar: app_bar(
              title: text(value: "Counter Demo")
            ),
            floating_action_button: fab(
              icon(icon: Ruflet::MaterialIcons::ADD),
              on_click: ->(_e) {
                @count += 1
                page.update(count_text, value: @count.to_s)
              }
            )
          )
        end
      end

      MainApp.new.run

    RUBY

    GEMFILE_TEMPLATE = <<~GEMFILE
      source "https://rubygems.org"

      gem "ruflet", ">= 0.0.3"
      gem "ruflet_server", ">= 0.0.3"
    GEMFILE

    README_TEMPLATE = <<~MD
      # %<app_name>s

      Ruflet app.

      ## Setup

      ```bash
      bundle install
      ```

      ## Run

      ```bash
      bundle exec ruflet run main
      ```

      ## Build

      ```bash
      bundle exec ruflet build apk
      bundle exec ruflet build ios
      ```
    MD
  end
end
