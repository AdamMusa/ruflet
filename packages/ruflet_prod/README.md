# RufletProd

RufletProd is a lightweight runtime that serves prebuilt Ruflet manifest JSON to the client.

## Includes

- RufletProd protocol (`RufletProd::Protocol`)
- RufletProd server (`RufletProd::Server`)
- Manifest runtime entry (`RufletProd.run`)

## Usage

```ruby
require "ruflet_prod"

manifest_path = File.expand_path("manifest.json", __dir__)
RufletProd.run(manifest_file: manifest_path)
```

`manifest.json` should be generated ahead of time by `ruflet build manifest`.

## Notes

- No `ruflet_ui` dependency in runtime.
- No dynamic Ruby UI DSL execution in `ruflet_prod`.
