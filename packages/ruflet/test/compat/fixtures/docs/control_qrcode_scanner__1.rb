# Docs example: content/docs/control_qrcode_scanner.md, line 27 (AdamMusa/ruflet_site 05dde18).
# Copied verbatim below this header; do not edit.
Ruflet.run do |page|
  result = text(value: "Point the camera at a code")

  scanner = qrcode_scanner(
    expand: true,
    formats: %i[qr_code data_matrix],
    detection_speed: :no_duplicates,
    on_detect: ->(event) {
      page.update(result, value: event.value.to_s)
    },
    on_error: ->(event) {
      page.update(result, value: event.data["message"].to_s)
    }
  )

  page.add(column(controls: [scanner, result]))
end
