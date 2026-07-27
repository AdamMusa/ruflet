# frozen_string_literal: true

require_relative "test_helper"

class QrCodeScannerExtensionTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "scanner-session",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def test_extension_registry_exposes_flutter_metadata_and_all_dsl_entrypoints
    registration = Ruflet::Extensions[:qrcode_scanner]

    assert registration
    assert_equal ["qrcode_scanner"], registration.helpers
    assert_equal "ruflet_qrcode_scanner", registration.flutter.fetch(:package)
    assert_respond_to Ruflet, :qrcode_scanner
    assert_respond_to Ruflet::UI, :qrcode_scanner
    assert_respond_to Ruflet::DSL, :qrcode_scanner
    assert_respond_to Ruflet::WidgetBuilder.new, :qrcode_scanner
  end

  def test_qrcode_scanner_serializes_typed_properties_and_events
    detected = ->(_event) {}
    scanner = Ruflet.qrcode_scanner(
      formats: %i[qr_code data_matrix],
      camera_facing: :back,
      detection_speed: :no_duplicates,
      fit: :cover,
      torch_enabled: false,
      on_detect: detected
    )

    assert_instance_of Ruflet::Extensions::QrCodeScannerControl, scanner
    assert_equal(
      {
        "_c" => "qrcode_scanner",
        "_i" => nil,
        "formats" => %w[qr_code data_matrix],
        "camera_facing" => "back",
        "detection_speed" => "no_duplicates",
        "fit" => "cover",
        "torch_enabled" => false,
        "on_detect" => true
      },
      scanner.to_patch
    )
    assert scanner.has_handler?(:detect)
  end

  def test_qrcode_scanner_methods_use_flet_invoke_names
    scanner = Ruflet.qrcode_scanner
    @page.add(scanner)

    scanner.start
    assert_equal "start", @sent.last.fetch(1).fetch("name")

    scanner.set_zoom_scale(0.75)
    assert_equal "set_zoom_scale", @sent.last.fetch(1).fetch("name")
    assert_equal({ "value" => 0.75 }, @sent.last.fetch(1).fetch("args"))

    scanner.toggle_torch
    assert_equal "toggle_torch", @sent.last.fetch(1).fetch("name")
  end

  def test_extension_schema_rejects_unknown_properties
    error = assert_raises(ArgumentError) { Ruflet.qrcode_scanner(not_a_scanner_property: true) }

    assert_includes error.message, "Unknown attribute"
  end
end
