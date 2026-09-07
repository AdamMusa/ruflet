# frozen_string_literal: true

require_relative "test_helper"

class PageStoragePathsServiceTest < Minitest::Test
  def test_storage_paths_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.storage_paths(data: { "source" => "studio" }, key: "paths")

    assert_equal "storagepaths", service.type
    assert_equal "StoragePaths", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "paths", service.props["key"]
    assert_same service, page.service(:storage_paths)
  end

  def test_get_temporary_directory_uses_flet_method_name
    sent = []
    page = build_page(sent)

    call_id = page.get_temporary_directory
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "get_temporary_directory" }
    refute_nil invoke_payload
    assert_nil invoke_payload["args"]
  end

  def test_get_application_documents_directory_returns_native_path_to_callback
    sent = []
    page = build_page(sent)
    callback_values = nil

    call_id = page.get_application_documents_directory(
      timeout: nil,
      on_result: ->(directory, error) { callback_values = [directory, error] }
    )

    invoke_payload = sent.reverse.map(&:last).find do |payload|
      payload["name"] == "get_application_documents_directory"
    end
    refute_nil invoke_payload
    assert_equal call_id, invoke_payload["call_id"]

    handled = page.handle_invoke_method_result(
      "call_id" => call_id,
      "result" => "/data/user/0/example/app_flutter",
      "error" => nil
    )

    assert handled
    assert_equal ["/data/user/0/example/app_flutter", nil], callback_values
  end

  def test_get_application_documents_directory_returns_native_error_to_callback
    sent = []
    page = build_page(sent)
    callback_values = nil

    call_id = page.get_application_documents_directory(
      timeout: nil,
      on_result: ->(directory, error) { callback_values = [directory, error] }
    )

    handled = page.handle_invoke_method_result(
      "call_id" => call_id,
      "result" => nil,
      "error" => "documents directory unavailable"
    )

    assert handled
    assert_equal [nil, "documents directory unavailable"], callback_values
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
