# frozen_string_literal: true

module Ruflet
  module CLI
    MAIN_TEMPLATE = <<~RUBY
    require "ruflet"
    Ruflet.run do |page|
      page.title = "Counter Demo"
      count = 0
      count_text = text(
        value: count.to_s,
        style: { size: 40, weight: "w700" }
      )
      page.floating_action_button = fab(
        icon: "add",
        on_click: ->(_e) do
          count += 1
          page.update(count_text, value: count.to_s)
        end
      )
      page.add(
        container(
          expand: true,
          alignment: Ruflet::MainAxisAlignment::CENTER,
          content: column(
            alignment: Ruflet::MainAxisAlignment::CENTER,
            horizontal_alignment: Ruflet::CrossAxisAlignment::CENTER,
            children: [
              text(value: "You have pushed the button this many times:"),
              count_text
            ]
          )
        )
      )
    end

    RUBY

    GEMFILE_TEMPLATE = <<~GEMFILE
      source "https://rubygems.org"

      gem "ruflet_core", ">= #{Ruflet::VERSION}"
      gem "ruflet_server", ">= #{Ruflet::VERSION}"
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
      ruflet run main
      ```

      ## Build

      ```bash
      ruflet build apk
      ruflet build ios
      ```
    MD
  end
end
