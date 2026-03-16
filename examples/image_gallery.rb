# frozen_string_literal: true

require "ruflet"

class ImageGalleryApp < Ruflet::App
  def view(page)
    page.title = "Image Gallery"
    page.scroll = "auto"

    page.add(
      container(
        padding: 16,
        content: column(
          scroll: "auto",
          spacing: 12,
          children: [
            text(value: "Vertical List (mix of web + local)", style: { size: 18 }),
            column(
              spacing: 8,
              children: [
                image(
                  "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800",
                  width: 300,
                  height: 170
                ),
                image(
                  "assets/splash.png",
                  width: 300,
                  height: 170
                ),
                image(
                  "assets/icon.png",
                  width: 300,
                  height: 170
                )
              ]
            ),
            text(value: "Horizontal List (web images)", style: { size: 18 }),
            container(
              height: 150,
              content: row(
                spacing: 8,
                scroll: "auto",
                children: [
                  image(
                    "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=400",
                    width: 220,
                    height: 140
                  ),
                  image(
                    "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=400",
                    width: 220,
                    height: 140
                  ),
                  image(
                    "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400",
                    width: 220,
                    height: 140
                  )
                ]
              )
            )
          ]
        )
      ),
      appbar: app_bar(title: text(value: "Image Gallery"))
    )
  end
end

ImageGalleryApp.new.run
