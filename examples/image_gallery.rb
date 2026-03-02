# frozen_string_literal: true

require "ruflet"

class ImageGalleryApp < Ruflet::App
  def view(page)
    page.title = "Image Gallery"
    page.scroll = "auto"

    page.add(
      page.container(
        padding: 16,
        content: page.column(
          scroll: "auto",
          spacing: 12,
          controls: [
            page.text(value: "Vertical List (mix of web + local)", size: 18),
            page.column(
              spacing: 8,
              controls: [
                page.image(
                  src: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800",
                  width: 300,
                  height: 170,
                  fit: "cover"
                ),
                page.image(
                  src: "assets/splash.png",
                  width: 300,
                  height: 170,
                  fit: "cover"
                ),
                page.image(
                  src: "assets/icon.png",
                  width: 300,
                  height: 170,
                  fit: "cover"
                )
              ]
            ),
            page.text(value: "Horizontal List (web images)", size: 18),
            page.container(
              height: 150,
              content: page.row(
                spacing: 8,
                scroll: "auto",
                controls: [
                  page.image(
                    src: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=400",
                    width: 220,
                    height: 140,
                    fit: "cover"
                  ),
                  page.image(
                    src: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=400",
                    width: 220,
                    height: 140,
                    fit: "cover"
                  ),
                  page.image(
                    src: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400",
                    width: 220,
                    height: 140,
                    fit: "cover"
                  )
                ]
              )
            )
          ]
        )
      ),
      appbar: page.app_bar(
        title: page.text(value: "Image Gallery")
      )
    )
  end
end

ImageGalleryApp.new.run
