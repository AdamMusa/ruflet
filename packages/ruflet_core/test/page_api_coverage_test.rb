# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/page_api_contract"

# Every public Ruflet::Page method is tested: either through a table in
# test/support/page_api_contract.rb (client calls, service accessors, page
# properties), whose tests PageApiContractTest generates, or by the test
# named here, which must exist and call it.
class PageApiCoverageTest < Minitest::Test
  COVERED_BY = {
    "add" => "page_compatibility_test#test_page_exposes_view_properties",
    "add_service" => "page_update_serialization_test#test_update_controls_survive_index_refresh_after_service_add",
    "apply_client_update" => "form_compatibility_test#test_validate_clears_errors_once_the_values_are_valid",
    "bottom_sheet" => "bottom_sheet_compatibility_test#test_bottomsheet_aliases_show_and_close_the_sheet",
    "bottom_sheet=" => "page_api_contract_test#test_bottom_sheet_writers_host_the_sheet_in_the_dialogs_container",
    "bottomsheet=" => "page_api_contract_test#test_bottom_sheet_writers_host_the_sheet_in_the_dialogs_container",
    "clean" => "page_compatibility_test#test_page_controls_insert_remove_remove_at_and_clean_match_flet_shape",
    "client_details" => "page_client_updates_test#test_live_brightness_is_available_before_the_callback_without_navigation",
    "close" => "alert_dialog_compatibility_test#test_page_open_and_close_are_flet_compatible_overlay_aliases",
    "close_banner" => "banner_compatibility_test#test_page_show_and_close_banner_helpers_target_the_given_banner",
    "close_bottom_sheet" => "bottom_sheet_compatibility_test#test_page_closes_current_bottom_sheet_without_an_argument",
    "close_bottomsheet" => "bottom_sheet_compatibility_test#test_bottomsheet_aliases_show_and_close_the_sheet",
    "close_dialog" => "about_dialog_compatibility_test#test_close_dialog_patches_open_false",
    "controls" => "page_compatibility_test#test_page_controls_writer_replaces_root_controls",
    "controls=" => "page_compatibility_test#test_page_controls_writer_replaces_root_controls",
    "dialog" => "date_picker_dialog_presentation_test#test_open_and_dialog_assignment_host_the_picker_the_same_way",
    "dialog=" => "date_picker_dialog_presentation_test#test_open_and_dialog_assignment_host_the_picker_the_same_way",
    "dispatch_event" => "page_compatibility_test#test_page_supports_theme_animation_and_views_pop_until_api",
    "fail_pending_invokes!" => "page_pending_invokes_test#test_fail_pending_invokes_ends_callbacks_and_waiters_with_the_error",
    "finalize_reload!" => "page_default_view_events_test#test_reset_for_reload_drops_page_handlers_the_reloaded_code_no_longer_sets",
    "get_control" => "page_compatibility_test#test_page_get_control_and_schedule_update",
    "get_device_info" => "page_device_info_test#test_get_device_info_invokes_the_page_and_wraps_the_record",
    "get_device_info_sync" => "page_device_info_test#test_get_device_info_sync_raises_the_client_error",
    "go" => "page_api_contract_test#test_go_sets_the_route_with_its_query_and_runs_on_route_change",
    "handle_invoke_method_result" => "page_device_info_test#test_get_device_info_sync_raises_the_client_error",
    "insert" => "page_compatibility_test#test_page_controls_insert_remove_remove_at_and_clean_match_flet_shape",
    "invoke" => "page_view_methods_test#test_page_level_methods_still_target_the_page",
    "invoke_sync" => "page_api_contract_test#test_invoke_sync_waits_for_the_reply_and_raises_its_error",
    "method_missing" => "page_api_contract_test#test_unknown_page_props_go_through_method_missing",
    "mount" => "dsl_prefixed_block_children_test#test_page_mount_collects_prefixed_children",
    "navigate" => "routes_compatibility_test#test_navigate_and_push_route_match_flet_route_helpers",
    "on" => "page_default_view_events_test#test_page_on_for_view_events_sets_the_view_flag",
    "on_route_change=" => "page_compatibility_test#test_page_dispatches_route_change_and_updates_route_from_client_event",
    "on_view_pop=" => "page_api_contract_test#test_on_view_pop_runs_when_the_client_pops_a_view",
    "on_views_pop_until=" => "page_compatibility_test#test_page_supports_theme_animation_and_views_pop_until_api",
    "open" => "dsl_presented_controls_test#test_qa_repro_dialog_opened_from_a_block_is_mounted_once",
    "overlay" => "page_compatibility_test#test_page_overlay_behaves_as_a_list_property",
    "overlay=" => "page_compatibility_test#test_page_overlay_behaves_as_a_list_property",
    "patch_page" => "page_api_contract_test#test_patch_page_updates_a_control_like_update",
    "pop_dialog" => "page_api_contract_test#test_pop_dialog_closes_the_open_dialog",
    "pop_views_until" => "page_pop_views_until_test#test_matches_the_first_view_with_the_route",
    "prepare_for_reconnect!" => "page_update_serialization_test#test_reconnect_republishes_page_shell_and_internal_roots",
    "push_route" => "routes_compatibility_test#test_navigate_and_push_route_match_flet_route_helpers",
    "query" => "routes_compatibility_test#test_query_reflects_client_route_changes",
    "register_page_patch" => "dsl_presented_controls_test#test_qa_repro_dialog_opened_from_a_block_is_mounted_once",
    "remove" => "page_compatibility_test#test_page_controls_insert_remove_remove_at_and_clean_match_flet_shape",
    "remove_at" => "page_compatibility_test#test_page_controls_insert_remove_remove_at_and_clean_match_flet_shape",
    "remove_service" => "page_api_contract_test#test_remove_service_takes_the_control_its_id_or_its_type",
    "replay_route_after_reload!" => "page_api_contract_test#test_replay_route_after_reload_reruns_on_route_change_once_unless_the_app_routed",
    "reset_for_reload!" => "page_default_view_events_test#test_reset_for_reload_drops_page_handlers_the_reloaded_code_no_longer_sets",
    "schedule_update" => "page_compatibility_test#test_page_get_control_and_schedule_update",
    "service" => "page_file_picker_service_test#test_pick_files_uses_existing_page_service",
    "services" => "page_file_picker_service_test#test_pick_files_uses_existing_page_service",
    "services=" => "page_api_contract_test#test_services_writer_replaces_the_mounted_services",
    "session_id" => "page_api_contract_test#test_session_id_is_the_one_the_page_was_built_with",
    "set_allowed_device_orientations" => "page_device_info_test#test_set_allowed_device_orientations_sends_flet_wire_values",
    "set_view_props" => "page_compatibility_test#test_page_serializes_flet_page_props_as_page_patch_ops",
    "show_banner" => "banner_compatibility_test#test_page_show_and_close_banner_helpers_target_the_given_banner",
    "show_bottom_sheet" => "bottom_sheet_compatibility_test#test_page_closes_current_bottom_sheet_without_an_argument",
    "show_bottomsheet" => "bottom_sheet_compatibility_test#test_bottomsheet_aliases_show_and_close_the_sheet",
    "show_dialog" => "page_compatibility_test#test_initial_page_patch_mounts_internal_containers_before_incremental_updates",
    "show_drawer" => "page_view_methods_test#test_drawer_methods_require_a_drawer_on_the_top_view",
    "show_end_drawer" => "page_view_methods_test#test_drawer_methods_require_a_drawer_on_the_top_view",
    "show_snack_bar" => "page_api_contract_test#test_snack_bar_writers_and_show_snack_bar_host_and_open_the_snack_bar",
    "show_snackbar" => "snack_bar_compatibility_test#test_snack_bar_action_and_visible_events_dispatch",
    "snack_bar" => "page_api_contract_test#test_snack_bar_writers_and_show_snack_bar_host_and_open_the_snack_bar",
    "snack_bar=" => "page_api_contract_test#test_snack_bar_writers_and_show_snack_bar_host_and_open_the_snack_bar",
    "snackbar=" => "page_api_contract_test#test_snack_bar_writers_and_show_snack_bar_host_and_open_the_snack_bar",
    "update" => "page_update_serialization_test#test_update_serializes_embedded_controls",
    "views" => "page_pop_views_until_test#test_matches_the_first_view_with_the_route",
    "views=" => "page_pop_views_until_test#test_matches_the_first_view_with_the_route",
    "web" => "page_compatibility_test#test_web_capability_defaults_to_false_when_client_omits_it",
    "web?" => "page_compatibility_test#test_web_capability_defaults_to_false_when_client_omits_it",
    "window" => "page_window_test#test_window_methods_match_flets_window_protocol"
  }.freeze

  def test_every_public_page_method_is_tested
    untested = page_methods - PageApiContract.listed_methods - COVERED_BY.keys

    assert_empty untested, "Page methods in no table of test/support/page_api_contract.rb and not in COVERED_BY"
  end

  def test_the_tables_name_only_public_page_methods
    listed = PageApiContract.listed_methods + COVERED_BY.keys

    assert_empty listed - page_methods
    assert_equal listed.uniq.size, listed.size, "a method is listed twice"
  end

  def test_each_covering_test_exists_and_calls_its_method
    COVERED_BY.each do |method_name, reference|
      file, test_name = reference.split("#")
      body = test_body(file, test_name)
      refute_nil body, "#{reference} (for Page##{method_name}) does not exist"

      called = method_name.end_with?("=") ? /page\.#{Regexp.escape(method_name.delete_suffix("="))}\s*=[^=]/ : /page\.#{Regexp.escape(method_name)}(?![\w=])/
      assert(body.match?(called) || test_name.include?(method_name.delete_suffix("=")),
             "#{reference} does not call Page##{method_name}")
    end
  end

  private

  def page_methods
    Ruflet::Page.public_instance_methods(false).map(&:to_s)
  end

  def test_body(file, test_name)
    path = File.join(__dir__, "#{file}.rb")
    return nil unless File.exist?(path)

    File.read(path, encoding: "utf-8")[/^  def #{Regexp.escape(test_name)}\n(.*?)^  end\n/m, 1]
  end
end
