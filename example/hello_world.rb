require "ruby_native"

class MyApp < RubyNative::App
  def view(page)
    page.vertical_alignment = RubyNative::MainAxisAlignment::CENTER
    page.horizontal_alignment = RubyNative::CrossAxisAlignment::CENTER
    page.title = "Hello"
    page.add(page.text(value: "Hello RubyNative"))
  end
end

MyApp.new.run