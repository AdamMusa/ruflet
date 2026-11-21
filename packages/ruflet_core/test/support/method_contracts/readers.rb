# frozen_string_literal: true

require_relative "../method_contract"

# The readers for the state the client writes back from user interaction
# (Ruflet::UI::ClientStateReaders): `field.value`, `tabs.selected_index` and
# so on. Each returns what the control's props hold and sends nothing. See
# test/support/method_contract.rb.
{
  "auto_complete" => %w[value],
  "checkbox" => %w[value],
  "chip" => %w[selected],
  "cupertino_checkbox" => %w[value],
  "cupertino_date_picker" => %w[value],
  "cupertino_navigation_bar" => %w[selected_index],
  "cupertino_picker" => %w[selected_index],
  "cupertino_segmented_button" => %w[selected_index],
  "cupertino_slider" => %w[value],
  "cupertino_sliding_segmented_button" => %w[selected_index],
  "cupertino_switch" => %w[value],
  "cupertino_text_field" => %w[selection value],
  "cupertino_timer_picker" => %w[value],
  "date_picker" => %w[entry_mode value],
  "date_range_picker" => %w[end_value start_value],
  "dropdown" => %w[value],
  "expansion_panel" => %w[expanded],
  "expansion_tile" => %w[expanded],
  "navigation_bar" => %w[selected_index],
  "navigation_drawer" => %w[selected_index],
  "navigation_rail" => %w[selected_index],
  "page_view" => %w[selected_index],
  "picker" => %w[selected_index],
  "radio_group" => %w[value],
  "range_slider" => %w[end_value start_value],
  "search_bar" => %w[value],
  "segmented_button" => %w[selected selected_index],
  "slider" => %w[value],
  "switch" => %w[value],
  "tabs" => %w[selected_index],
  "text_field" => %w[selection value],
  "time_picker" => %w[entry_mode value],
  "timer_picker" => %w[value]
}.each do |type, names|
  MethodContract.define(
    type => names.to_h do |name|
      [name, { local: %(returns props["#{name}"], which the client writes back (client_state_readers_test)) }]
    end
  )
end
