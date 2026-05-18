# frozen_string_literal: true

require_relative "test_helper"

class PageFilePickerServiceTest < Minitest::Test
  def test_file_picker_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    picker = page.file_picker(data: { "source" => "studio" }, key: "picker")

    assert_equal "filepicker", picker.type
    assert_equal "FilePicker", picker.to_patch["_c"]
    assert_equal({ "source" => "studio" }, picker.props["data"])
    assert_equal "picker", picker.props["key"]
    assert_same picker, page.service(:file_picker)
  end

  def test_file_picker_keeps_event_handlers
    sent = []
    page = build_page(sent)

    picker = page.file_picker(on_result: ->(_event) {}, on_upload: ->(_event) {})

    assert picker.has_handler?(:result)
    assert picker.has_handler?(:upload)
    assert_equal true, picker.props["on_result"]
    assert_equal true, picker.props["on_upload"]
  end

  def test_service_uses_snake_case_name_without_duplicate_compact_flet_type
    sent = []
    page = build_page(sent)

    first = page.service(:file_picker)
    second = page.service(:file_picker)

    assert_same first, second
    assert_equal ["filepicker"], page.services.map(&:type)
  end

  def test_pick_files_uses_existing_page_service
    sent = []
    page = build_page(sent)
    picker = page.service(:file_picker)

    page.pick_files

    assert_same picker, page.service(:file_picker)
    assert_equal [picker], page.services
  end

  def test_pick_files_omits_nil_options_and_includes_flet_defaults
    sent = []
    page = build_page(sent)

    call_id = page.pick_files(allow_multiple: true, with_data: true)
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "pick_files" }
    refute_nil invoke_payload
    assert_equal(
      {
        "file_type" => "any",
        "allow_multiple" => true,
        "with_data" => true
      },
      invoke_payload["args"]
    )
  end

  def test_save_file_omits_nil_options_and_serializes_src_bytes
    sent = []
    page = build_page(sent)

    call_id = page.save_file(file_name: "notes.txt", src_bytes: "hello")
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "save_file" }
    refute_nil invoke_payload
    assert_equal(
      {
        "file_name" => "notes.txt",
        "file_type" => "any",
        "src_bytes" => "hello"
      },
      invoke_payload["args"]
    )
  end

  def test_get_directory_path_omits_nil_options
    sent = []
    page = build_page(sent)

    call_id = page.get_directory_path
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "get_directory_path" }
    refute_nil invoke_payload
    assert_equal({}, invoke_payload["args"])
  end

  def test_upload_uses_flet_file_picker_signature
    sent = []
    page = build_page(sent)

    files = [{ name: "a.txt", upload_url: "/upload/a.txt", method: "PUT" }]
    call_id = page.upload(files)
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "upload" }
    refute_nil invoke_payload
    assert_equal(
      {
        "files" => [
          {
            "name" => "a.txt",
            "upload_url" => "/upload/a.txt",
            "method" => "PUT"
          }
        ]
      },
      invoke_payload["args"]
    )
  end

  def test_upload_files_alias_keeps_existing_ruflet_api
    sent = []
    page = build_page(sent)

    call_id = page.upload_files([{ name: "a.txt" }])
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "upload" }
    refute_nil invoke_payload
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end
