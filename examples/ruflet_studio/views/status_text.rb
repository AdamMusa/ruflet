# frozen_string_literal: true

module RufletStudio
  module Views
    def status_text(page)
      page.text(value: "Ready", size: 12, color: "#9aa0a6")
    end
  end
end
