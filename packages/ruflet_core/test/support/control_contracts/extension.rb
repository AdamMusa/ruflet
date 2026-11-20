# frozen_string_literal: true

require_relative "../control_contract"

# Contract specs for the extension controls Ruflet ships (lib/ruflet_ui/ruflet/extensions).
# See test/support/control_contract.rb for the options and what they assert.

module ControlContract
  define(
    "extension",
    {
      "qrcode_scanner" => {
        wire: "qrcode_scanner",
        samples: { formats: %w[qr_code ean_13] }
      }
    }
  )
end
