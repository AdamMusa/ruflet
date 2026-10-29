# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      # Imperative focus for controls whose client renderers handle the
      # "focus" invoke: buttons, icon buttons, dropdowns and text fields.
      module FocusableMethods
        def focus(timeout: 10, on_result: nil)
          runtime_page&.invoke(self, "focus", args: {}, timeout: timeout, on_result: on_result)
        end
      end

      # Text inputs can also give up focus, which dismisses the soft keyboard.
      module TextInputMethods
        include FocusableMethods

        def blur(timeout: 10, on_result: nil)
          runtime_page&.invoke(self, "blur", args: {}, timeout: timeout, on_result: on_result)
        end
      end
    end
  end
end
