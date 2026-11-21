# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      # Opens and closes the drawers of a control whose renderer owns a
      # Scaffold: a View (view.dart) or a Pagelet (pagelet.dart). As Flet's
      # View and Pagelet methods, each invokes the client method of the same
      # name; a control that is not mounted on a page yet has no client and
      # the call returns nil. page.show_drawer and friends do the same for the
      # top view.
      module DrawerMethods
        def show_drawer(timeout: 10, on_result: nil)
          runtime_page&.invoke(self, "show_drawer", timeout: timeout, on_result: on_result)
        end

        def close_drawer(timeout: 10, on_result: nil)
          runtime_page&.invoke(self, "close_drawer", timeout: timeout, on_result: on_result)
        end

        def show_end_drawer(timeout: 10, on_result: nil)
          runtime_page&.invoke(self, "show_end_drawer", timeout: timeout, on_result: on_result)
        end

        def close_end_drawer(timeout: 10, on_result: nil)
          runtime_page&.invoke(self, "close_end_drawer", timeout: timeout, on_result: on_result)
        end
      end
    end
  end
end
