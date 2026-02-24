require "ruby_native"
class LayoutApp < RubyNative::App
  def view(page)
    page.add(
      page.column(spacing: 12) do
        text value: "Line 1"
        text value: "Line 2"
      end
    )
  end
end

LayoutApp.new.run