# frozen_string_literal: true

module RufletStudio
  module SectionsMedia
    def build_webview(_page, _status)
      webview_control = web_view(
        url: "https://rubyonrails.org/",
        method: "get",
        expand: true
      )
      container(
        expand: true,
        content: webview_control
      )
    end
  end
end
