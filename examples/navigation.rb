require "ruflet"

class MainApp < Ruflet::App
  def view(page)
    page.title = "Navigation: Go + Replace"

    page.on_route_change = ->(_e) { render(page) }
    page.on_view_pop = ->(_e) { handle_back(page) }

    render(page)
  end

  private

  def render(page)
    route = route_path(page.route)

    if route == "/replace"
      page.views = [replace_view(page)]
    elsif route == "/go"
      # Keep Home in stack so back navigation returns to Home.
      page.views = [home_view(page), go_view(page)]
    else
      page.views = [home_view(page)]
    end

    page.update
  end

  def handle_back(page)
    # Replace flow keeps single-page stack; back always returns home.
    page.go("/")
  end

  def home_view(page)
    widget(
      :view,
      route: "/",
      appbar: app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: text(value: "Home", size: 18)
      ),
      padding: 16,
      controls: [
        text(value: "Home Screen", size: 24),
        text(value: "Tap to go to Replace screen using page.go()."),
        button(
          text: "Go to Go Screen (with back nav)",
          on_click: ->(_e) { page.go("/go", nav: "go") }
        ),
        button(
          text: "Go to Replace",
          on_click: ->(_e) { page.go("/replace", nav: "go") }
        )
      ]
    )
  end

  def replace_view(page)
    widget(
      :view,
      route: "/replace",
      appbar: app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: text(value: "Replace", size: 18)
      ),
      padding: 16,
      controls: [
        text(value: "Replace Screen", size: 24),
        text(value: "Current route: #{page.route}"),
        text(value: "Use replace below to return Home without back stack."),
        button(
          text: "Replace with Home",
          on_click: ->(_e) { page.go("/", nav: "replace") }
        )
      ]
    )
  end

  def go_view(page)
    widget(
      :view,
      route: "/go",
      appbar: app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: text(value: "Go Screen", size: 18)
      ),
      padding: 16,
      controls: [
        text(value: "Go Screen", size: 24),
        text(value: "Opened via page.go('/go')."),
        text(value: "Back navigation should return to Home."),
        button(
          text: "Go Back Home",
          on_click: ->(_e) { page.go("/", nav: "go") }
        )
      ]
    )
  end

  def route_path(route)
    route.to_s.split("?").first
  end
end

MainApp.new.run
