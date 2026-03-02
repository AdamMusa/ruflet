# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_audio(page, status)
      page.column(
        spacing: 8,
        controls: [
          status,
          page.text(
            value: "Audio control is not available in this build.",
            color: "#9aa0a6"
          )
        ]
      )
    end
  end
end
