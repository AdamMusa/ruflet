# ruflet_qrcode_scanner

The first-party Ruflet QR and barcode scanner extension. It is a standard Flet
Flutter extension: the public library exports `Extension`, `Extension` extends
`FletExtension`, and `createWidget()` handles the `qrcode_scanner` control type.
There is no client adapter layer.

## Use from Ruby

Enable the package for the generated client:

```yaml
# ruflet.yaml
extensions:
  - qrcode_scanner
```

Ruflet adds the Android and Apple camera declarations automatically. An
explicit service entry is optional and lets you customize the iOS permission
message:

```yaml
# services.yaml
services:
  - camera:
      description: Scan QR codes and product barcodes.
```

Use the typed Ruflet DSL—no Dart object or Ruby class constructor is needed:

```ruby
require "ruflet"

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
```

Run it directly with `ruflet run main.rb`.

## API

Scanner properties (defaults in parentheses):

- `auto_start` (`true`)
- `auto_zoom` (`false`, Android only)
- `camera_facing` (`:back`; `:back` or `:front`)
- `detection_speed` (`:normal`; `:normal`, `:no_duplicates`, or `:unrestricted`)
- `detection_timeout` (`250` milliseconds; used by normal detection)
- `fit` (`:cover`)
- `formats` (`[]`, meaning all supported formats)
- `invert_image` (`false`, Android only)
- `return_image` (`false`; Android, iOS, and macOS)
- `scan_window` (`nil`; `{ left:, top:, right:, bottom: }` or `{ x:, y:, width:, height: }`)
- `tap_to_focus` (`false`)
- `torch_enabled` (`false`)
- `zoom_scale` (`1.0`)

It also accepts Ruflet's common layout properties: `align`, `animate_align`,
`animate_margin`, `animate_offset`, `animate_opacity`, `animate_position`,
`animate_rotation`, `animate_scale`, `animate_size`, `aspect_ratio`, `badge`,
`bottom`, `col`, `data`, `disabled`, `expand`, `expand_loose`, `height`, `key`,
`left`, `margin`, `offset`, `opacity`, `right`, `rotate`, `rtl`, `scale`,
`size_change_interval`, `tooltip`, `top`, `visible`, and `width`.

`formats` accepts `all`, `unknown`, `aztec`, `codabar`, `code_39`, `code_93`,
`code_128`, `data_bar`, `data_bar_expanded`, `data_bar_limited`, `data_matrix`,
`ean_8`, `ean_13`, `itf_2_of_5`, `itf_2_of_5_with_checksum`, `itf_14`,
`maxi_code`, `micro_qr_code`, `pdf_417`, `qr_code`, `upc_a`, and `upc_e`.
Unsupported values are ignored by the Flutter package.

Events:

- `on_detect`: `event.value` is the first raw value. `event.data["barcodes"]`
  contains every result with `raw_value`, `display_value`, `format`, `type`, and
  optional `corners`. When `return_image` is enabled, `event.data["image"]` is
  the base64 capture when the platform supplies one.
- `on_error`: `event.data["message"]` and `event.data["type"]` describe the
  failure.
- `on_animation_end` and `on_size_change`: inherited layout events.

Mounted scanners expose asynchronous `start`, `stop`, `switch_camera`,
`toggle_torch`, `set_zoom_scale(value)`, and `reset_zoom_scale` methods. Every
method accepts `timeout:` and `on_result:` like other Ruflet invoke methods.

## Platforms and development

`mobile_scanner` supports Android, iOS, macOS, and web. Linux and Windows are
not supported. Browser camera access requires a secure context. Native hosts
require iOS 13+, macOS 10.15+, Android compile SDK 34+, Java 17, and Flutter
3.27+.

Validate this package with:

```sh
flutter analyze
flutter test
```
