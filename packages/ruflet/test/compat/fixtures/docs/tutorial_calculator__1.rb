# Docs example: content/docs/tutorial_calculator.md, line 24 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
require "ruflet"

class CalculatorApp < Ruflet::App
  def view(page)
    page.title = "Calculator"

    page.add(
      container(
        width: 420,
        padding: 16,
        border_radius: 16,
        content: text(value: "Calculator coming next...")
      )
    )
  end
end

CalculatorApp.new.run
