# frozen_string_literal: true

module Ruflet
  module CLI
    MAIN_TEMPLATE = <<~RUBY
    require "ruflet"
    Ruflet.run do |page|
      page.title = "Counter Demo"
      count = 0
      count_text = text(count.to_s, style: {size: 40})
      page.add(
        container(
          expand: true,
          alignment: Ruflet::MainAxisAlignment::CENTER,
          content: column(
            alignment: Ruflet::MainAxisAlignment::CENTER,
            horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
            children: [
              text("You have pushed the button this many times:"),
              count_text
            ]
          )
        ),
        floating_action_button: fab(
          icon: Ruflet::MaterialIcons::ADD,
          on_click: ->(_e) do
            count += 1
            page.update(count_text, value: count.to_s)
          end
        )
      )
    end

    RUBY

    GEMFILE_TEMPLATE = <<~GEMFILE
      source "https://rubygems.org"

      gem "ruflet_core", ">= 0.0.10"
      gem "ruflet_server", ">= 0.0.10"
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
