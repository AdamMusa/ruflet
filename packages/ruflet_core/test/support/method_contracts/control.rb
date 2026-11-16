# frozen_string_literal: true

require_relative "../method_contract"

# What each control method sends the client. See test/support/method_contract.rb.

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
      "open" => { sends: {} }
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
      "reset" => {  },
      "restore_state" => {  },
      "save_state" => {  },
      "zoom" => { args: ["sample:factor"], sends: {"factor" => "sample:factor"} }
    },
    "list_view" => {
      "end_refresh" => {  },
      "scroll_to" => { sends: {} }
    },
    "map" => {
      "center_on" => { args: ["sample:point"], sends: {"point" => "sample:point"} },
      "move_to" => { sends: {} },
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
      "go_to_page" => { args: ["sample:index"], sends: {"index" => "sample:index"} },
      "jump_to" => { args: ["sample:value"], sends: {"value" => "sample:value"} },
      "jump_to_page" => { args: ["sample:index"], sends: {"index" => "sample:index"} },
      "next_page" => { sends: {} },
      "previous_page" => { sends: {} }
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
      "move_to" => { args: ["sample:index"], sends: {"index" => "sample:index"} }
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
      "playlist_add" => { sends: {"media" => {}} },
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
      "load_file" => { args: ["sample:path"], sends: {"path" => "sample:path"} },
      "load_html" => { args: ["sample:value"], sends: {"value" => "sample:value"} },
      "load_request" => { args: ["sample:url"], sends: {"url" => "sample:url", "method" => "get"} },
      "reload" => {  },
      "run_javascript" => { args: ["sample:value"], sends: {"value" => "sample:value"} },
      "scroll_by" => { args: [10, 20], sends: {"x" => 10, "y" => 20} },
      "scroll_to" => { args: [0, 480], sends: {"x" => 0, "y" => 480} },
      "set_javascript_mode" => { args: ["sample:mode"], sends: {"mode" => "sample:mode"} }
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
