# frozen_string_literal: true

require "pathname"
require "uri"
require_relative "../method_contract"

# What each control method sends the client. See test/support/method_contract.rb.
# A method that converts an argument (to_s, to_i, a Symbol name, coordinates)
# gets a value the conversion changes, so the spec fails without it.

MethodContract.define(
  {
    "audio" => {
      "get_current_position" => {  },
      "get_duration" => {  },
      "pause" => {  },
      "play" => { sends: {"position" => 0} },
      "release" => {  },
      "resume" => {  },
      "seek" => { args: ["sample:position_milliseconds"], sends: {"position" => "sample:position_milliseconds"} }
    },
    "button" => {
      "focus" => { sends: {} }
    },
    "canvas" => {
      "capture" => { sends: {} },
      "clear_capture" => { sends: {} },
      "get_capture" => { sends: {} }
    },
    "carousel_view" => {
      "animate_to_item" => { args: ["sample:index"], sends: {"index" => "sample:index", "duration" => 300, "curve" => "ease"} }
    },
    "code_editor" => {
      "focus" => {  },
      "fold_at" => { args: ["sample:line_number"], sends: {"line_number" => "sample:line_number"} },
      "fold_comment_at_line_zero" => {  },
      "fold_imports" => {  }
    },
    "column" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "context_menu" => {
      "open" => { kwargs: { position: { x: 10, y: 20 } }, sends: {"position" => {"x" => 10, "y" => 20}} }
    },
    "cupertino_button" => {
      "focus" => { sends: {} }
    },
    "cupertino_filled_button" => {
      "focus" => { sends: {} }
    },
    "cupertino_text_field" => {
      "blur" => { sends: {} },
      "focus" => { sends: {} }
    },
    "cupertino_tinted_button" => {
      "focus" => { sends: {} }
    },
    "draggable_scrollable_sheet" => {
      "animate_to" => { args: ["sample:size"], sends: {"size" => "sample:size", "duration" => 300, "curve" => "easeOut"} },
      "jump_to" => { args: ["sample:size"], sends: {"size" => "sample:size"} }
    },
    "dropdown" => {
      "attach_handler" => { local: "registers a handler, mapping the Material 2 change onto select (dropdown_compatibility_test)" },
      "focus" => { sends: {} },
      "on" => { local: "registers a handler, mapping the Material 2 change onto select (dropdown_compatibility_test)" }
    },
    "expansion_panel_list" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "filled_button" => {
      "focus" => { sends: {} }
    },
    "filled_icon_button" => {
      "focus" => { sends: {} }
    },
    "filled_tonal_button" => {
      "focus" => { sends: {} }
    },
    "filled_tonal_icon_button" => {
      "focus" => { sends: {} }
    },
    "nested_scroll_view" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "form" => {
      "end_refresh" => {  },
      "errors" => { local: "the fields' messages from the last validate (form_compatibility_test)" },
      "fields" => { local: "the form fields under the form (form_compatibility_test)" },
      "handle_field_event" => { local: "the page routes field events here for autovalidation and on_submit (form_compatibility_test)" },
      "reset" => { local: "restores the values at mount through a page update (form_compatibility_test)" },
      "save" => { local: "runs each field's on_saved in Ruby (form_compatibility_test)" },
      "scroll_to" => { sends: {} },
      "sync_form_fields!" => { local: "links fields to the form when the page mounts it (form_compatibility_test)" },
      "validate" => { local: "runs the validators in Ruby and sends the error props in one page update (form_compatibility_test)" },
      "values" => { local: "the fields' values, keyed by key or id (form_compatibility_test)" }
    },
    "grid_view" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "icon_button" => {
      "focus" => { sends: {} }
    },
    "interstitial_ad" => {
      "show" => {  }
    },
    "interactive_viewer" => {
      "pan" => { args: ["sample:dx"], sends: {"dx" => "sample:dx", "dy" => 0, "dz" => 0} },
      "reset" => { kwargs: { animation_duration: { milliseconds: 300 } }, sends: {"animation_duration" => {"milliseconds" => 300}} },
      "restore_state" => {  },
      "save_state" => {  },
      "zoom" => { args: ["sample:factor"], sends: {"factor" => "sample:factor"} }
    },
    "list_view" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "map" => {
      "center_on" => { args: [[1.5, 2.5]], kwargs: { zoom: 9 }, sends: {"point" => {"latitude" => 1.5, "longitude" => 2.5}, "zoom" => 9} },
      "move_to" => { kwargs: { destination: { lat: 1.5, lng: 2.5 }, zoom: 9, animation_duration: 300, animation_curve: :ease_in }, sends: {"destination" => {"latitude" => 1.5, "longitude" => 2.5}, "zoom" => 9, "duration" => 300, "curve" => "ease_in"} },
      "reset_rotation" => { sends: {} },
      "rotate_from" => { args: ["sample:degree"], sends: {"degree" => "sample:degree"} },
      "zoom_in" => { sends: {} },
      "zoom_out" => { sends: {} },
      "zoom_to" => { args: ["sample:zoom"], sends: {"zoom" => "sample:zoom"} }
    },
    "outlined_button" => {
      "focus" => { sends: {} }
    },
    "outlined_icon_button" => {
      "focus" => { sends: {} }
    },
    "page_view" => {
      "go_to_page" => { args: ["sample:index"], kwargs: { duration: 250, curve: :ease_in_out }, sends: {"index" => "sample:index", "duration" => 250, "curve" => "ease_in_out"} },
      "jump_to" => { args: ["sample:value"], sends: {"value" => "sample:value"} },
      "jump_to_page" => { args: ["sample:index"], sends: {"index" => "sample:index"} },
      "next_page" => { kwargs: { duration: 250, curve: :ease_in }, sends: {"duration" => 250, "curve" => "ease_in"} },
      "previous_page" => { kwargs: { curve: :ease_out }, sends: {"curve" => "ease_out"} }
    },
    "reorderable_list_view" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "responsive_row" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "row" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "screenshot" => {
      "capture" => {  }
    },
    "search_bar" => {
      "close_view" => { sends: {} },
      "focus" => {  },
      "open_view" => {  }
    },
    "tabs" => {
      "move_to" => { args: ["sample:index"], kwargs: { duration: 250, curve: :ease_in }, sends: {"index" => "sample:index", "duration" => 250, "curve" => "ease_in"} }
    },
    "text_button" => {
      "focus" => { sends: {} }
    },
    "text_field" => {
      "blur" => { sends: {} },
      "focus" => { sends: {} }
    },
    "video" => {
      "get_current_position" => {  },
      "get_duration" => {  },
      "is_completed" => {  },
      "is_playing" => {  },
      "jump_to" => { args: ["sample:media_index"], sends: {"media_index" => "sample:media_index"} },
      "next" => {  },
      "pause" => {  },
      "play" => {  },
      "play_or_pause" => {  },
      "playlist_add" => { args: [{ resource: "a.mp4", http_headers: { auth: "x" } }], sends: {"media" => {"resource" => "a.mp4", "http_headers" => {"auth" => "x"}}} },
      "playlist_remove" => { args: ["sample:media_index"], sends: {"media_index" => "sample:media_index"} },
      "previous" => {  },
      "seek" => { args: ["sample:position_milliseconds"], sends: {"position" => "sample:position_milliseconds"} },
      "stop" => {  }
    },
    "web_view" => {
      "can_go_back" => {  },
      "can_go_forward" => {  },
      "clear_cache" => {  },
      "clear_local_storage" => {  },
      "disable_zoom" => {  },
      "enable_zoom" => {  },
      "get_current_url" => {  },
      "get_title" => {  },
      "get_user_agent" => {  },
      "go_back" => {  },
      "go_forward" => {  },
      "load_file" => { args: [Pathname("/www/index.html")], sends: {"path" => "/www/index.html"} },
      "load_html" => { args: [:"<p>hi</p>"], kwargs: { base_url: URI("https://example.com/") }, sends: {"value" => "<p>hi</p>", "base_url" => "https://example.com/"} },
      "load_request" => { args: [URI("https://example.com/")], kwargs: { method: :post }, sends: {"url" => "https://example.com/", "method" => "post"} },
      "reload" => {  },
      "run_javascript" => { args: [:"alert(1)"], sends: {"value" => "alert(1)"} },
      "scroll_by" => { args: [10.5, "20"], sends: {"x" => 10, "y" => 20} },
      "scroll_to" => { args: ["12", 480.9], sends: {"x" => 12, "y" => 480} },
      "set_javascript_mode" => { args: [:unrestricted], sends: {"mode" => "unrestricted"} }
    },
    "view" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "window" => {
      "center" => {  },
      "close" => {  },
      "destroy" => {  },
      "start_dragging" => {  },
      "start_resizing" => { args: ["sample:edge"], sends: {"edge" => "sample:edge"} },
      "to_front" => {  },
      "wait_until_ready_to_show" => {  }
    },
    "qrcode_scanner" => {
      "reset_zoom_scale" => {  },
      "set_zoom_scale" => { args: ["sample:value"], sends: {"value" => "sample:value"} },
      "start" => {  },
      "stop" => {  },
      "switch_camera" => {  },
      "toggle_torch" => {  }
    }
  }
)
