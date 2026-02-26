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
    page.view(
      route: "/",
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Home", size: 18)
      ),
      padding: 16,
      controls: [
        page.text(value: "Home Screen", size: 24),
        page.text(value: "Tap to go to Replace screen using page.go()."),
        page.button(
          text: "Go to Go Screen (with back nav)",
          on_click: ->(_e) { page.go("/go", nav: "go") }
        ),
        page.button(
          text: "Go to Replace",
          on_click: ->(_e) { page.go("/replace", nav: "go") }
        )
      ]
    )
  end

  def replace_view(page)
    page.view(
      route: "/replace",
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Replace", size: 18)
      ),
      padding: 16,
      controls: [
        page.text(value: "Replace Screen", size: 24),
        page.text(value: "Current route: #{page.route}"),
        page.text(value: "Use replace below to return Home without back stack."),
        page.button(
          text: "Replace with Home",
          on_click: ->(_e) { page.go("/", nav: "replace") }
        )
      ]
    )
  end

  def go_view(page)
    page.view(
      route: "/go",
      appbar: page.app_bar(
        bgcolor: "#d9d7db",
        color: "#232329",
        title: page.text(value: "Go Screen", size: 18)
      ),
      padding: 16,
      controls: [
        page.text(value: "Go Screen", size: 24),
        page.text(value: "Opened via page.go('/go')."),
        page.text(value: "Back navigation should return to Home."),
        page.button(
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
