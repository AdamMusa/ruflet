# frozen_string_literal: true

# What each public Ruflet::Page method does on the wire, by kind. Every public
# Page method is in one of these tables or in PageApiCoverageTest::COVERED_BY
# (see test/page_api_coverage_test.rb).
module PageApiContract
  # Methods that call a client method. target: is the service type the call
  # goes to (the page mounts that service on first use), :page (control id 1)
  # or :view (the page's view). The other options are as in
  # test/support/method_contract.rb: args:, name: (default the Ruby name) and
  # sends: (the args payload, default nil).
  INVOKES = {
      "battery_save_mode?" => { target: "battery", name: "is_in_battery_save_mode" },
      "can_launch_url" => { target: "urllauncher", args: ["sample:url"], sends: {"url" => "sample:url"} },
      "close_drawer" => { target: :view },
      "close_end_drawer" => { target: :view },
      "close_in_app_web_view" => { target: "urllauncher" },
      "get_application_cache_directory" => { target: "storagepaths" },
      "get_application_documents_directory" => { target: "storagepaths" },
      "get_application_support_directory" => { target: "storagepaths" },
      "get_battery_level" => { target: "battery" },
      "get_battery_state" => { target: "battery" },
      "get_clipboard" => { target: "clipboard", name: "get" },
      "get_clipboard_files" => { target: "clipboard", name: "get_files" },
      "get_clipboard_image" => { target: "clipboard", name: "get_image" },
      "get_connectivity" => { target: "connectivity" },
      "get_console_log_filename" => { target: "storagepaths" },
      "get_directory_path" => { target: "filepicker", sends: {} },
      "get_downloads_directory" => { target: "storagepaths" },
      "get_external_cache_directories" => { target: "storagepaths" },
      "get_external_storage_directories" => { target: "storagepaths" },
      "get_external_storage_directory" => { target: "storagepaths" },
      "get_library_directory" => { target: "storagepaths" },
      "get_temporary_directory" => { target: "storagepaths" },
      "heavy_impact" => { target: "hapticfeedback" },
      "is_in_battery_save_mode" => { target: "battery" },
      "launch_url" => { target: "urllauncher", args: ["sample:url"], sends: {"url" => "sample:url"} },
      "light_impact" => { target: "hapticfeedback" },
      "medium_impact" => { target: "hapticfeedback" },
      "open_window" => { target: "urllauncher", args: ["sample:url"], sends: {"url" => "sample:url"} },
      "pick_files" => { target: "filepicker", sends: {"file_type" => "any", "allow_multiple" => false, "with_data" => false} },
      "save_file" => { target: "filepicker", sends: {"file_type" => "any"} },
      "scroll_to" => { target: :view, sends: {"offset" => nil, "delta" => nil, "scroll_key" => nil, "duration" => nil, "curve" => nil} },
      "selection_click" => { target: "hapticfeedback" },
      "set_clipboard" => { target: "clipboard", args: ["sample:value"], name: "set", sends: {"data" => "sample:value"} },
      "set_clipboard_files" => { target: "clipboard", args: ["sample:files"], name: "set_files", sends: {"files" => ["sample:files"]} },
      "set_clipboard_image" => { target: "clipboard", args: ["sample:value"], name: "set_image", sends: {"data" => "sample:value"} },
      "share_files" => { target: "share", sends: {"download_fallback_enabled" => true, "mail_to_fallback_enabled" => true} },
      "share_text" => { target: "share", sends: {"download_fallback_enabled" => true, "mail_to_fallback_enabled" => true} },
      "share_uri" => { target: "share", sends: {} },
      "supports_close_for_launch_mode" => { target: "urllauncher", args: ["sample:mode"], sends: {"mode" => "sample:mode"} },
      "supports_launch_mode" => { target: "urllauncher", args: ["sample:mode"], sends: {"mode" => "sample:mode"} },
      "upload" => { target: "filepicker", args: ["sample:files"], sends: {"files" => ["sample:files"]} },
      "upload_files" => { target: "filepicker", args: ["sample:files"], name: "upload", sends: {"files" => ["sample:files"]} },
      "vibrate" => { target: "hapticfeedback" }
  }.freeze

  # Service accessors: page.<name>(**props) mounts a service of this type in
  # the page's service registry and returns it.
  SERVICES = {
    "accelerometer" => "accelerometer", "audio" => "audio", "audio_recorder" => "audiorecorder",
    "barometer" => "barometer", "battery" => "battery", "clipboard" => "clipboard",
    "connectivity" => "connectivity", "file_picker" => "filepicker", "flashlight" => "flashlight",
    "geolocator" => "geolocator", "gyroscope" => "gyroscope", "haptic_feedback" => "hapticfeedback",
    "local_auth" => "localauthentication", "local_authentication" => "localauthentication",
    "magnetometer" => "magnetometer", "permission_handler" => "permissionhandler",
    "screen_brightness" => "screenbrightness", "secure_storage" => "securestorage",
    "semantics_service" => "semanticsservice", "shake_detector" => "shakedetector", "share" => "share",
    "shared_preferences" => "sharedpreferences", "storage_paths" => "storagepaths",
    "url_launcher" => "urllauncher", "user_accelerometer" => "useraccelerometer", "wakelock" => "wakelock"
  }.freeze

  # Called without props, these four return a proxy object instead of the
  # service; the proxies' methods are covered in page_<name>_service_test.
  PROXIES = %w[flashlight screen_brightness shared_preferences wakelock].freeze

  # Visual controls the page builds but does not mount: the app places them.
  VISUAL = { "camera" => {}, "screenshot" => { content: -> { Ruflet.text("x") } } }.freeze

  # Page properties: the reader and the writer, and where page.update sends
  # the value: on the page itself or on its view.
  PROPS = {
    "title" => :page, "horizontal_alignment" => :page, "vertical_alignment" => :page,
    "route" => :view, "bgcolor" => :view, "padding" => :view, "spacing" => :view,
    "decoration" => :view, "foreground_decoration" => :view, "auto_scroll" => :view,
    "floating_action_button_location" => :view, "appbar" => :view, "bottom_appbar" => :view,
    "navigation_bar" => :view, "drawer" => :view, "end_drawer" => :view,
    "floating_action_button" => :view, "browser_context_menu" => :view
  }.freeze

  # Writers spelled differently from their reader.
  WRITER_ALIASES = { "bottomappbar=" => "bottom_appbar" }.freeze

  def self.listed_methods
    INVOKES.keys + SERVICES.keys + VISUAL.keys +
      PROPS.keys.flat_map { |name| [name, "#{name}="] } + WRITER_ALIASES.keys
  end
end
