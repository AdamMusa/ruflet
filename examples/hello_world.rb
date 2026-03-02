require "ruflet"

class MyApp < Ruflet::App
  def view(page)
    page.vertical_alignment = Ruflet::MainAxisAlignment::CENTER
    page.horizontal_alignment = Ruflet::CrossAxisAlignment::CENTER
    page.title = "Hello"
    page.add(page.text(value: "Hello Ruflet"))
  end
end

MyApp.new.run