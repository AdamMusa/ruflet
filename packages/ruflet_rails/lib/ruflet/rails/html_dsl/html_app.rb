# frozen_string_literal: true

require "uri"
require "erb"
require "json"

module Ruflet
  module Rails
    module HtmlDsl
      # HTML-over-the-wire native UI: Rails renders HTML DSL markup and this
      # app turns each page into a screen of real Ruflet controls — no
      # WebView. Links push native screens, `on-click` actions round-trip to
      # Rails and re-render the current screen in place, forms post their
      # field values and render the response.
      class HtmlApp
        Screen = Struct.new(:url, :view, :route, :root, :fields, :csrf_token, :title,
                            :appbar_sig, :fab_sig, :nav_sig, :body, :markup, keyword_init: true)

        # Event handlers stay bound to the screen whose markup declared them,
        # so a control on a covered screen still targets the right state.
        class ScreenHandlers
          def initialize(app, screen)
            @app = app
            @screen = screen
          end

          def navigate(url, mode) = @app.navigate(url, mode, from: @screen)
          def action(method:, url:) = @app.action(method: method, url: url, from: @screen)
          def submit_form(form) = @app.submit_form(form, from: @screen)
          def field_changed(name, value) = @screen.fields[name] = value
          def service(spec) = @app.run_service(spec)
          def control_event(spec, event) = @app.handle_control_event(spec, event)
        end

        def initialize(page, start_url:, title: nil, fetcher: nil)
          @page = page
          @start_url = start_url.to_s
          @title = title
          @fetcher = fetcher || default_fetcher
          @screens = []
          @route_seq = 0
          @service_request_token = 0
        end

        def start
          @page.on_view_pop = ->(_event) { pop }
          push_screen(@start_url, root: true)
          self
        end

        # Screens are rendered in the session itself, with no request behind
        # them, so the whole session stays on its single WebSocket thread.
        def default_fetcher
          TemplateSource.new
        end

        # --- navigation ---------------------------------------------------------

        def navigate(url, mode, from: nil)
          url = absolute_url(url)
          case mode.to_s
          when "back"
            pop
          when "root"
            @screens.clear
            push_screen(url, root: true)
          when "replace"
            @screens.pop
            push_screen(url, root: @screens.empty?)
          else
            push_screen(url, root: @screens.empty?)
          end
        end

        # An `on-click` action: request the URL, then re-render the source
        # screen in place with the returned markup (Rails redirects are
        # followed by the fetcher, so `redirect_to` re-renders the target).
        def action(method:, url:, from: nil)
          screen = from || @screens.last
          return unless screen

          response = request(method, absolute_url(url), screen: screen)
          rerender(screen, response)
        end

        def submit_form(form, from: nil)
          screen = from || @screens.last
          return unless screen

          params = form[:fields].keys.each_with_object({}) do |name, collected|
            value = screen.fields.key?(name) ? screen.fields[name] : form[:fields][name]
            collected[name] = value.nil? ? "" : value
          end
          response = request(form[:method], absolute_url(form[:action]), params: params, screen: screen)
          rerender(screen, response)
        end

        def pop
          return if @screens.size <= 1

          invalidate_pending_services
          @screens.pop
          flush
        end

        # A pending service result belongs to the screen that asked for it.
        # Bumping the request token when the stack changes means a slow result
        # that lands after the user has navigated away is ignored, instead of
        # surfacing on whatever screen happens to be visible now.
        def invalidate_pending_services
          @service_request_token += 1
        end

        # Run a native platform service in response to a tap
        # (`<button service="copy" text="…">`). Everything the device can do is
        # reachable this way: the tap invokes the matching native method and,
        # for anything that returns data or can fail, the result comes back in
        # a native result dialog. Streaming services can target an inline Text
        # control instead, so rapid readings do not cover the application UI.
        def run_service(spec)
          @service_request_token += 1
          @service_result_target = spec["result-target"]
          name = spec["service"].to_s.downcase.tr("_", "-")
          case name
          # --- clipboard --------------------------------------------------------
          when "copy", "clipboard", "clipboard-set"
            @page.set_clipboard(spec["text"].to_s)
            show_service_result(spec["toast"] || "Copied to clipboard", title: "Clipboard",
                                                                          target: @service_result_target)
          when "paste", "read-clipboard", "clipboard-get"
            @page.get_clipboard(on_result: report("Clipboard", show_result: true))
          when "clipboard-set-files"
            @page.set_clipboard_files(array_value(spec["files"]), on_result: report("Clipboard files saved"))
          when "clipboard-get-files"
            @page.get_clipboard_files(on_result: report("Clipboard files", show_result: true))
          when "clipboard-set-image"
            @page.set_clipboard_image(spec["value"] || spec["data"], on_result: report("Clipboard image saved"))
          when "clipboard-get-image"
            @page.get_clipboard_image(on_result: report("Clipboard image", show_result: true))
          # --- share ------------------------------------------------------------
          when "share", "share-text"
            @page.share_text(spec["text"].to_s, title: spec["title"], subject: spec["subject"],
                                                     on_result: report(spec["toast"] || "Share sheet opened"))
          when "share-link", "share-url", "share-uri"
            @page.share_uri((spec["uri"] || spec["url"]).to_s, on_result: report("Share sheet opened"))
          when "share-files"
            @page.share_files(array_value(spec["files"]), text: spec["text"], title: spec["title"],
                                                          subject: spec["subject"],
                                                          on_result: report("Share sheet opened"))
          # --- haptics ----------------------------------------------------------
          when "haptic", "vibrate"
            run_haptic(spec["style"])
            show_service_result(spec["toast"] || "Haptic feedback", title: "Haptics",
                                                                     target: @service_result_target)
          # --- links ------------------------------------------------------------
          when "launch", "open", "url"
            @page.launch_url(spec["url"].to_s, mode: spec["mode"], on_result: report("Link opened"))
          when "can-launch"
            invoke_named_service("url_launcher", "can_launch_url", { "url" => spec["url"] }, "Can launch")
          when "open-window"
            @page.open_window(spec["url"].to_s, title: spec["title"], width: spec["width"],
                                                     height: spec["height"], on_result: report("Window opened"))
          when "close-in-app-web-view"
            @page.close_in_app_web_view(on_result: report("In-app browser closed"))
          # --- hardware ---------------------------------------------------------
          when "flashlight", "torch"
            toggle_flashlight
          when "flashlight-on", "torch-on"
            @page.flashlight.on(on_result: report("Torch on"))
            @flashlight_on = true
          when "flashlight-off", "torch-off"
            @page.flashlight.off(on_result: report("Torch off"))
            @flashlight_on = false
          when "flashlight-available"
            @page.flashlight.is_available(on_result: report("Flashlight available", show_result: true))
          when "wakelock", "keep-awake"
            toggle_wakelock
          when "wakelock-enable"
            @page.wakelock.enable(on_result: report("Staying awake"))
            @wakelock_on = true
          when "wakelock-disable"
            @page.wakelock.disable(on_result: report("Sleep allowed"))
            @wakelock_on = false
          when "wakelock-status"
            @page.wakelock.is_enabled(on_result: report("Wakelock enabled", show_result: true))
          when "brightness"
            level = clamp_unit(spec["value"], 0.5)
            @page.screen_brightness.set_application_screen_brightness(
              level, on_result: report("Brightness #{(level * 100).round}%")
            )
          when "brightness-get", "brightness-application"
            invoke_named_service("screen_brightness", "get_application_screen_brightness", nil,
                                 "Application brightness", show_result: true)
          when "brightness-system-get"
            invoke_named_service("screen_brightness", "get_system_screen_brightness", nil,
                                 "System brightness", show_result: true)
          when "brightness-can-change-system"
            invoke_named_service("screen_brightness", "can_change_system_screen_brightness", nil,
                                 "Can change system brightness", show_result: true)
          when "brightness-animate-get"
            invoke_named_service("screen_brightness", "is_animate", nil,
                                 "Brightness animation", show_result: true)
          when "brightness-auto-reset-get"
            invoke_named_service("screen_brightness", "is_auto_reset", nil,
                                 "Brightness auto reset", show_result: true)
          when "brightness-system"
            level = clamp_unit(spec["value"], 0.5)
            @page.screen_brightness.set_system_screen_brightness(
              level, on_result: report("System brightness #{(level * 100).round}%")
            )
          when "brightness-animate-set"
            invoke_named_service("screen_brightness", "set_animate", { "value" => truthy?(spec["value"]) },
                                 "Brightness animation")
          when "brightness-auto-reset-set"
            invoke_named_service("screen_brightness", "set_auto_reset", { "value" => truthy?(spec["value"]) },
                                 "Brightness auto reset")
          when "brightness-reset"
            invoke_named_service("screen_brightness", "reset_application_screen_brightness", nil,
                                 "Application brightness reset")
          # --- queries ----------------------------------------------------------
          when "battery"
            read_battery
          when "battery-level"
            @page.get_battery_level(on_result: report("Battery level", show_result: true))
          when "battery-state"
            @page.get_battery_state(on_result: report("Battery state", show_result: true))
          when "battery-save-mode"
            @page.is_in_battery_save_mode(on_result: report("Battery save mode", show_result: true))
          when "connectivity"
            @page.get_connectivity(on_result: report("Connectivity", show_result: true))
          when "location", "geolocate", "position"
            geolocator.get_current_position(on_result: report("Position", show_result: true))
          when "location-last"
            geolocator.get_last_known_position(on_result: report("Last position", show_result: true))
          when "location-permission"
            geolocator.get_permission_status(on_result: report("Location permission", show_result: true))
          when "location-request-permission"
            geolocator.request_permission(on_result: report("Location permission", show_result: true))
          when "location-service-enabled"
            geolocator.is_location_service_enabled(on_result: report("Location service", show_result: true))
          when "location-open-settings"
            geolocator.open_location_settings(on_result: report("Location settings opened"))
          when "location-open-app-settings"
            geolocator.open_app_settings(on_result: report("App settings opened"))
          when "location-distance"
            geolocator.distance_between(
              spec["start-latitude"], spec["start-longitude"], spec["end-latitude"], spec["end-longitude"],
              on_result: report("Distance", show_result: true)
            )
          # --- secure storage ---------------------------------------------------
          when "secure-set"
            secure_storage.set(spec["key"].to_s, spec["value"].to_s, on_result: report("Stored securely"))
          when "secure-get"
            secure_storage.get(spec["key"].to_s, on_result: report("Secure value", show_result: true))
          when "secure-contains"
            secure_storage.contains_key(spec["key"].to_s,
                                        on_result: report("Secure key exists", show_result: true))
          when "secure-all"
            secure_storage.get_all(on_result: report("Secure values", show_result: true))
          when "secure-remove"
            secure_storage.remove(spec["key"].to_s, on_result: report("Secure value removed"))
          when "secure-clear"
            secure_storage.clear(on_result: report("Secure storage cleared"))
          when "secure-availability"
            secure_storage.get_availability(on_result: report("Secure storage", show_result: true))
          # --- shared preferences -----------------------------------------------
          when "prefs-set", "preference-set"
            @page.shared_preferences.set(spec["key"].to_s, spec["value"],
                                         on_result: report("Preference saved"))
          when "prefs-get", "preference-get"
            @page.shared_preferences.get(spec["key"].to_s, on_result: report("Preference", show_result: true))
          when "prefs-contains", "preference-contains"
            @page.shared_preferences.contains_key(
              spec["key"].to_s, on_result: report("Preference exists", show_result: true)
            )
          when "prefs-keys", "preference-keys"
            @page.shared_preferences.get_keys(
              spec["prefix"], on_result: report("Preference keys", show_result: true)
            )
          when "prefs-remove", "preference-remove"
            @page.shared_preferences.remove(spec["key"].to_s, on_result: report("Preference removed"))
          when "prefs-clear", "preference-clear"
            @page.shared_preferences.clear(on_result: report("Preferences cleared"))
          # --- permissions ------------------------------------------------------
          when "permission", "request-permission"
            permissions.request(spec["name"].to_s, timeout: interactive_timeout(spec),
                                                   on_result: report("Permission", show_result: true))
          when "permission-status"
            permissions.get_status(spec["name"].to_s, on_result: report("Permission", show_result: true))
          when "permission-settings"
            permissions.open_app_settings(on_result: report("App settings opened"))
          # --- files and paths ---------------------------------------------------
          when "pick-files", "file-picker"
            @page.pick_files(
              dialog_title: spec["dialog-title"], initial_directory: spec["initial-directory"],
              file_type: spec["file-type"] || "any",
              allowed_extensions: array_value(spec["allowed-extensions"]),
              allow_multiple: truthy?(spec["allow-multiple"]), with_data: truthy?(spec["with-data"]),
              timeout: interactive_timeout(spec),
              on_result: report("Selected files", show_result: true)
            )
          when "pick-directory", "directory-picker"
            @page.get_directory_path(
              dialog_title: spec["dialog-title"], initial_directory: spec["initial-directory"],
              timeout: interactive_timeout(spec),
              on_result: report("Selected directory", show_result: true)
            )
          when "save-file"
            @page.save_file(
              dialog_title: spec["dialog-title"], file_name: spec["file-name"],
              initial_directory: spec["initial-directory"], file_type: spec["file-type"] || "any",
              allowed_extensions: array_value(spec["allowed-extensions"]),
              src_bytes: binary_bytes(spec["src-bytes"]),
              timeout: interactive_timeout(spec),
              on_result: report("Saved file", show_result: true)
            )
          when /\Astorage-(.+)\z/
            method = storage_path_method(Regexp.last_match(1))
            method ? @page.public_send(method, on_result: report("Storage path", show_result: true)) :
              show_service_result("Unknown storage path: #{Regexp.last_match(1)}", title: "Storage path")
          # --- accessibility and recording --------------------------------------
          when "announce", "semantics-announce"
            semantics.announce_message(
              spec["message"] || spec["text"], rtl: truthy?(spec["rtl"]),
              assertiveness: spec["assertiveness"] || "polite",
              on_result: report("Accessibility message announced")
            )
          when "semantics-tooltip"
            semantics.announce_tooltip(spec["message"] || spec["text"],
                                       on_result: report("Accessibility tooltip announced"))
          when "semantics-features"
            semantics.get_accessibility_features(
              on_result: report("Accessibility features", show_result: true)
            )
          when /\Aaudio-recorder-(.+)\z/
            run_audio_recorder(Regexp.last_match(1), spec)
          when /\A(accelerometer|user-accelerometer|gyroscope|magnetometer|barometer)-(start|stop)\z/
            toggle_sensor(Regexp.last_match(1), Regexp.last_match(2), spec)
          when "camera-open", "camera-initialize"
            open_camera(spec)
          when "camera-capture", "camera-take-picture"
            capture_camera_picture(spec)
          # --- extension controls and generic service escape hatch --------------
          when "control"
            invoke_target_control(spec)
          else
            invoke_generic_service(name, spec)
          end
        rescue StandardError => e
          show_service_result(e.message, title: "#{service_label(name)} failed",
                                         target: @service_result_target)
        end

        # Declarative extension callback used by ERB attributes such as:
        #   on-loaded-target="audio-status" on-loaded-message="Audio loaded"
        #   on-change-control="demo-rive" on-change-property="speed_multiplier"
        def handle_control_event(spec, event)
          data = event.respond_to?(:data) ? event.data : event
          value = if data.is_a?(Hash)
                    data["value"] || data[:value] || (data.one? ? data.values.first : data)
                  else
                    data
                  end

          if spec["control"] && spec["property"]
            control = @page.get_control(spec["control"].to_s)
            @page.update(control, spec["property"].to_s.tr("-", "_").to_sym => value) if control
          end

          # The event can re-run a whole service (e.g. battery re-reads level /
          # state / saver on `on_state_change`), which reports for itself.
          if spec["service"]
            return run_service("service" => spec["service"], "result-target" => spec["result-target"])
          end

          target = spec["target"]
          return unless target

          message = spec["message"]
          message = "#{spec['prefix']}#{format_service_value(value)}" if message.to_s.empty?
          show_service_result(message, target: target)
        end

        private

        # --- screens --------------------------------------------------------------

        # A new screen is fetched and rendered atomically, then pushed as one
        # complete View. Painting a placeholder first (spinner + a guessed app
        # bar) only to swap it for the real chrome makes the screen visibly
        # flicker/shake; a single push lets the client run one clean transition.
        def push_screen(url, root: false)
          url = absolute_url(url)
          return if url.empty?

          invalidate_pending_services
          screen = Screen.new(url: url, root: root, fields: {})
          screen.route = root ? "/" : "/screen/#{@route_seq += 1}"
          response = request("get", url, screen: screen)
          result = render_result(screen, response)
          screen.view = build_view(screen, result)
          remember_chrome(screen, result)
          @screens.push(screen)
          # The service registry may immediately send a page update. Put the
          # completed screen on the stack first so that first update already
          # contains the real view instead of an empty/previous screen.
          mount_services(result)
          flush
          run_on_load(result)
          screen
        end

        # Run each `on-load` service once the screen is mounted and its services
        # are registered — Studio's build-time `refresh_info.call` that fills a
        # panel (battery, screen brightness, …) before the user taps anything.
        def run_on_load(result)
          Array(result.on_load).each { |spec| run_service(spec) }
        rescue StandardError
          nil
        end

        # Mount a screen's declared services (`<geolocator>`, `<battery>`, …) on
        # the page's service registry so they register with the client. Each
        # screen owns its services; navigating replaces them.
        # Services are what `invoke` targets. If mounting fails the control
        # never reaches the client, every later invoke waits for an answer that
        # cannot come, and the screen reports "execution expired" — a timeout
        # standing in for a mount error nobody saw. Swallowing the cause here
        # is what made camera/recorder/audio failures unreadable, so say it.
        def mount_services(result)
          return unless @page.respond_to?(:services=)

          @page.services = result.services
        rescue StandardError => e
          warn "[ruflet_rails] mounting services failed: #{e.class}: #{e.message}"
          show_service_result("Services could not be mounted: #{e.message}",
                              title: "Screen services failed")
        end

        # Attributes the DSL consumes itself. Everything else on a service
        # element becomes a native invoke argument, so anything that is really
        # markup — the button's own styling, its icon, its variant, the
        # `on-load` marker — has to be named here. It is not cosmetic: a `play`
        # that arrives carrying `class`/`icon`/`variant` is a call the client
        # cannot match to the control's method signature, which is exactly how
        # the ERB audio buttons ended up doing nothing at all.
        SERVICE_META_KEYS = %w[
          service method target args toast timeout result-target capture-target preview-target id disabled
          class icon variant on-load file-name output-path path configuration upload encoder
        ].freeze

        # Declarative event wiring (`on-loaded-target`, `on-error-prefix`, …) is
        # markup too, and there is one per event, so match them by shape.
        DECLARED_EVENT_ATTRIBUTE = /\Aon-.+-(?:target|service|prefix|message|control|property|result-target)\z/

        STORAGE_PATH_METHODS = {
          "cache" => :get_application_cache_directory,
          "documents" => :get_application_documents_directory,
          "support" => :get_application_support_directory,
          "downloads" => :get_downloads_directory,
          "external-cache" => :get_external_cache_directories,
          "external-storage-directories" => :get_external_storage_directories,
          "external-storage" => :get_external_storage_directory,
          "library" => :get_library_directory,
          "temporary" => :get_temporary_directory,
          "temp" => :get_temporary_directory,
          "console-log" => :get_console_log_filename
        }.freeze

        def storage_path_method(name)
          STORAGE_PATH_METHODS[name.to_s.tr("_", "-")]
        end

        # Reuse the service the screen already mounted (matched by type) without
        # passing any props to it. Passing props to an existing service merges
        # and RE-REGISTERS it — a service-container update sent right before we
        # invoke, which can make the client tear down and rebuild the control at
        # the very moment the invoke arrives (→ "execution expired"). Studio never
        # re-touches a service after creating it; this mirrors that. Only when the
        # screen declared no such service do we create one, with a stable key.
        def reuse_service(type, key)
          compact = type.to_s.delete("_").downcase
          existing = @page.services.find do |service|
            service.respond_to?(:type) && service.type.to_s.delete("_").downcase == compact
          end
          existing || @page.service(type, key: key)
        end

        def geolocator
          reuse_service(:geolocator, "ruflet_rails_geolocator")
        end

        def semantics
          reuse_service(:semantics_service, "ruflet_rails_semantics")
        end

        def run_audio_recorder(action, spec)
          recorder = reuse_service(:audio_recorder, "ruflet_rails_audio_recorder")
          callback = report("Audio recorder #{action.tr('-', ' ')}", show_result: true)
          case action
          when "start"
            start_audio_recording(recorder, spec)
          when "stop"
            stop_audio_recording(recorder, spec)
          when "supported-encoder"
            recorder.is_supported_encoder(spec["encoder"], on_result: callback)
          else
            method = "#{action.tr('-', '_')}_recording"
            method = action.tr("-", "_") if recorder.respond_to?(action.tr("-", "_"))
            raise ArgumentError, "unknown recorder action #{action.inspect}" unless recorder.respond_to?(method)

            recorder.public_send(method, on_result: callback)
          end
        end

        # Recording needs a writable file path *on the device*, and the mic
        # permission has to be granted first. Studio establishes the same
        # sequence; Rails asks PermissionHandler explicitly because the record
        # plugin's `has_permission` preflight can remain pending on an iOS
        # simulator before the system prompt has ever been shown.
        def start_audio_recording(recorder, spec)
          target = spec["result-target"]
          configuration = spec["configuration"] || { "encoder" => "wav" }
          explicit = (spec["output-path"] || spec["path"]).to_s

          begin_recording = lambda do |file|
            start_native_recording = lambda do
              recorder.start_recording(
                output_path: file, configuration: configuration, upload: spec["upload"],
                timeout: interactive_timeout(spec),
                on_result: lambda do |*rec|
                  if service_error?(rec[1])
                    next show_service_result("Start error: #{rec[1]}",
                                             title: "Audio recorder failed", target: target)
                  end
                  unless rec[0]
                    next show_service_result("The recorder could not start.",
                                             title: "Audio recorder failed", target: target)
                  end

                  set_audio_recording_state(spec, recording: true)
                  show_service_result("Recording… Speak now.", title: "Audio recorder", target: target)
                end
              )
            end

            if @recording_microphone_permission_granted
              start_native_recording.call
              next
            end

            permissions = reuse_service(:permission_handler, "ruflet_rails_permissions")
            permissions.request("microphone", timeout: interactive_timeout(spec), on_result: lambda do |*out|
              permission_status, perm_error = out
              if service_error?(perm_error)
                next show_service_result("Recorder permission error: #{perm_error}",
                                         title: "Audio recorder failed", target: target)
              end
              unless microphone_permission_granted?(permission_status)
                next show_service_result("Microphone permission was not granted.",
                                         title: "Audio recorder", target: target)
              end

              @recording_microphone_permission_granted = true
              start_native_recording.call
            end)
          end

          release_recording_playback do
            next begin_recording.call(explicit) unless explicit.empty?

            show_service_result("Preparing recording…", title: "Audio recorder", target: target)
            if @recording_documents_directory
              file_name = spec["file-name"].to_s
              file_name = next_recording_file_name if file_name.empty?
              next begin_recording.call("#{@recording_documents_directory}/#{file_name}")
            end

            @page.get_application_documents_directory(on_result: lambda do |dir, dir_error|
              if service_error?(dir_error) || dir.to_s.empty?
                next show_service_result(
                  "Recording path error: #{dir_error || 'documents directory unavailable'}",
                  title: "Audio recorder failed", target: target
                )
              end

              @recording_documents_directory = dir.to_s.sub(%r{/+\z}, "")
              requested_name = spec["file-name"].to_s
              file_name = requested_name.empty? ? next_recording_file_name : requested_name
              file = "#{@recording_documents_directory}/#{file_name}"
              begin_recording.call(file)
            end)
          end
        end

        def next_recording_file_name
          @recording_sequence = @recording_sequence.to_i + 1
          "ruflet_recording_#{@recording_sequence}.wav"
        end

        def release_recording_playback(&after_release)
          @recording_playback_generation = @recording_playback_generation.to_i + 1
          previous = @recording_playback
          @recording_playback = nil
          return after_release.call unless previous

          # A completed native player does not consistently answer a `release`
          # invocation. Removing the service disposes the player and must not
          # block the next recording session on an optional callback.
          @page.remove_service(previous)
          after_release.call
        end

        def microphone_permission_granted?(status)
          status == true || status.to_s == "granted"
        end

        def stop_audio_recording(recorder, spec)
          target = spec["result-target"]
          recorder.stop_recording(on_result: lambda do |path, error|
            set_audio_recording_state(spec, recording: false)
            if service_error?(error)
              next show_service_result("Stop error: #{error}",
                                       title: "Audio recorder failed", target: target)
            end
            if path.to_s.empty?
              next show_service_result("Recording stopped, but no audio file was returned.",
                                       title: "Audio recorder failed", target: target)
            end

            autoplay_recording(path.to_s, target: target)
          end)
        end

        def set_audio_recording_state(spec, recording:)
          update_control_property(spec["indicator-target"], visible: recording)
          update_control_property(spec["record-target"], disabled: recording)
          update_control_property(spec["stop-target"], disabled: !recording)
        end

        def update_control_property(id, **props)
          return if id.to_s.empty?

          control = @page.get_control(id.to_s)
          @page.update(control, **props) if control
        end

        def autoplay_recording(path, target:)
          @page.remove_service(@recording_playback) if @recording_playback
          @recording_playback_generation = @recording_playback_generation.to_i + 1
          generation = @recording_playback_generation
          @recording_playback = @page.service(
            :audio,
            id: "ruflet_rails_recording_playback",
            src: path,
            autoplay: true,
            release_mode: "stop",
            on_state_change: lambda do |event|
              next unless generation == @recording_playback_generation

              data = event.respond_to?(:data) ? event.data : event
              state = data.is_a?(Hash) ? (data["state"] || data[:state]) : data
              message = case state.to_s
                        when "playing" then "Playing your recording…"
                        when "completed", "stopped" then "Recording saved and playback finished."
                        end
              show_service_result(message, target: target) if message
            end,
            on_error: lambda do |event|
              next unless generation == @recording_playback_generation

              data = event.respond_to?(:data) ? event.data : event
              show_service_result("Playback error: #{format_service_value(data)}",
                                  title: "Audio playback failed", target: target)
            end
          )
          show_service_result("Saved. Playing your recording…", title: "Audio recorder", target: target)
        end

        def toggle_sensor(type, action, spec)
          type = type.tr("-", "_")
          sensor = @page.service(
            type,
            key: "ruflet_rails_#{type}",
            interval: spec["interval"],
            cancel_on_error: spec["cancel-on-error"],
            on_reading: lambda { |event|
              show_service_result(
                format_service_value(event_data(event)),
                title: service_label(type),
                target: spec["result-target"]
              )
            },
            on_error: lambda { |event|
              show_service_result(
                format_service_value(event_data(event)),
                title: "#{service_label(type)} failed",
                target: spec["result-target"]
              )
            }
          )
          enabled = action == "start"
          @page.update(sensor, enabled: enabled)
          show_service_result(
            "#{service_label(type)} #{enabled ? 'started' : 'stopped'}",
            title: "Sensor",
            target: spec["result-target"]
          )
        end

        def event_data(event)
          event.respond_to?(:data) ? event.data : event
        end

        def open_camera(spec)
          request_token = @service_request_token
          camera = target_control!(spec, default: "demo-camera")
          result_target = spec["result-target"]
          capture_target = spec["capture-target"]
          preview_target = spec["preview-target"]
          show_service_result("Checking available cameras…", title: "Camera", target: result_target)
          @page.invoke(
            camera,
            "get_available_cameras",
            # On a real device this is the call that raises the camera
            # permission prompt, so it waits on the person, not the hardware.
            timeout: interactive_timeout(spec),
            on_result: lambda do |cameras, camera_error|
              next unless current_service_request?(request_token)

              if service_error?(camera_error)
                show_service_result(camera_error, title: "Camera failed", target: result_target)
                next
              end

              description = Array(cameras).first
              unless description
                show_service_result("No camera is available on this device.", title: "Camera",
                                     target: result_target)
                next
              end

              show_service_result("Initializing camera…", title: "Camera", target: result_target)
              @page.invoke(
                camera,
                "initialize",
                args: {
                  "description" => description,
                  "resolution_preset" => spec["resolution-preset"] || "medium",
                  "enable_audio" => truthy?(spec["enable-audio"]),
                  "image_format_group" => spec["image-format-group"] || "jpeg"
                },
                timeout: [service_timeout(spec), 180].max,
                on_result: lambda do |_result, init_error|
                  next unless current_service_request?(request_token)

                  if service_error?(init_error)
                    show_service_result(init_error, title: "Camera initialization failed",
                                                    target: result_target)
                  else
                    if capture_target && (capture_button = @page.get_control(capture_target))
                      @page.update(capture_button, disabled: false)
                    end
                    if preview_target && (preview = @page.get_control(preview_target))
                      @page.update(preview, height: 320)
                    end
                    show_service_result("Camera initialized and preview is ready.", title: "Camera",
                                                                                  target: result_target)
                  end
                end
              )
            end
          )
        end

        def capture_camera_picture(spec)
          request_token = @service_request_token
          camera = target_control!(spec, default: "demo-camera")
          result_target = spec["result-target"]
          show_service_result("Taking picture…", title: "Camera", target: result_target)
          @page.invoke(
            camera,
            "take_picture",
            timeout: [service_timeout(spec), 45].max,
            on_result: lambda do |result, error|
              next unless current_service_request?(request_token)

              if service_error?(error)
                show_service_result(error, title: "Camera capture failed", target: result_target)
              else
                bytes = result.respond_to?(:bytesize) ? result.bytesize : Array(result).length
                show_service_result("Captured #{bytes} bytes.", title: "Camera", target: result_target)
              end
            end
          )
        end

        # Invoke a method on an inline extension control. Give the control an
        # `id` in ERB and target it from a service button:
        #   <%= audio id: "player", src: "..." %>
        #   <%= button "Play", service: "control", target: "player", method: "play" %>
        def invoke_target_control(spec)
          target = spec["target"].to_s
          method = spec["method"].to_s.tr("-", "_")
          raise ArgumentError, "target is required" if target.empty?
          raise ArgumentError, "method is required" if method.empty?

          control = target_control!(spec)

          args = service_args(spec)
          if method == "update"
            @page.update(control, **args.transform_keys(&:to_sym))
            show_service_result(spec["toast"] || "#{service_label(target)} updated",
                                title: "Extension", target: spec["result-target"])
          else
            @page.invoke(
              control, method, args: args.empty? ? nil : args,
              timeout: service_timeout(spec), on_result: report(spec["toast"] || service_label(method), show_result: true)
            )
          end
        end

        def target_control!(spec, default: nil)
          target = (spec["target"] || default).to_s
          raise ArgumentError, "target is required" if target.empty?

          control = @page.get_control(target)
          raise ArgumentError, "control #{target.inspect} was not found" unless control

          control
        end

        # Open-ended form for services that do not need a convenience alias:
        #   service="geolocator" method="get_current_position"
        #   service="secure-storage.get_all"
        # Any non-metadata attributes (or an `args` JSON object) become invoke
        # arguments. This keeps new Ruflet service methods usable without a
        # ruflet_rails release for every method addition.
        def invoke_generic_service(name, spec)
          service_name, dotted_method = name.split(".", 2)
          method = (spec["method"] || dotted_method).to_s.tr("-", "_")
          raise ArgumentError, "unknown service #{name.inspect}" if method.empty?

          invoke_named_service(
            service_name.tr("-", "_"), method, service_args(spec),
            spec["toast"] || service_label(method), show_result: true,
            timeout: service_timeout(spec)
          )
        end

        def invoke_named_service(type, method, args, label, show_result: false, timeout: 10)
          control = @page.service(type)
          @page.invoke(
            control, method, args: args.nil? || args.empty? ? nil : args,
            timeout: timeout, on_result: report(label, show_result: show_result)
          )
        end

        def service_args(spec)
          args = spec["args"].is_a?(Hash) ? spec["args"].dup : {}
          spec.each do |key, value|
            next if SERVICE_META_KEYS.include?(key)
            next if DECLARED_EVENT_ATTRIBUTE.match?(key)
            next if value.nil?

            args[key.tr("-", "_")] = value
          end
          args
        end

        def service_timeout(spec)
          value = spec["timeout"]
          value.nil? || value.to_s.empty? ? 10 : value.to_f
        end

        # Anything that puts a system dialog on screen — a permission prompt, a
        # file picker, a save sheet — waits on a person, not on the device, so
        # the 10s default expires while they are still reading it.
        #
        # But a long ceiling only helps the case where an answer is coming. If
        # the plugin is missing or never replies, every extra second is dead
        # time the user spends staring at a screen that will fail anyway. 30s
        # covers answering a dialog without turning a broken call into a
        # half-minute hang; markup can raise it with `timeout=` where a flow
        # genuinely needs longer.
        INTERACTIVE_TIMEOUT = 30

        def interactive_timeout(spec)
          declared = spec["timeout"]
          return declared.to_f unless declared.nil? || declared.to_s.empty?

          INTERACTIVE_TIMEOUT
        end

        # HTML attributes are text, but the client's file APIs want bytes.
        # Msgpack sends a binary-encoded String as `bin`, which arrives as the
        # Uint8List those APIs declare; a UTF-8 String arrives as a Dart String
        # and fails their cast.
        def binary_bytes(value)
          return nil if value.nil?
          return value if value.respond_to?(:encoding) && value.encoding == Encoding::BINARY

          value.to_s.dup.force_encoding(Encoding::BINARY)
        end

        def truthy?(value)
          value == true || %w[1 true yes on].include?(value.to_s.downcase)
        end

        def array_value(value)
          return value if value.is_a?(Array)
          return [] if value.nil? || value.to_s.empty?

          value.to_s.split(",").map(&:strip).reject(&:empty?)
        end

        def service_label(value)
          value.to_s.tr("_.-", "   ").split.map(&:capitalize).join(" ")
        end

        def run_haptic(style)
          case style.to_s.downcase
          when "heavy" then @page.heavy_impact
          when "medium" then @page.medium_impact
          when "light" then @page.light_impact
          when "vibrate" then @page.vibrate
          else @page.selection_click
          end
        end

        def toggle_flashlight
          @flashlight_on = !@flashlight_on
          label = @flashlight_on ? "Torch on" : "Torch off"
          if @flashlight_on
            @page.flashlight.on(on_result: report(label))
          else
            @page.flashlight.off(on_result: report(label))
          end
        end

        def toggle_wakelock
          @wakelock_on = !@wakelock_on
          label = @wakelock_on ? "Staying awake" : "Sleep allowed"
          if @wakelock_on
            @page.wakelock.enable(on_result: report(label))
          else
            @page.wakelock.disable(on_result: report(label))
          end
        end

        # Chained battery read: level, then charging state, reported together.
        def read_battery
          request_token = @service_request_token
          result_target = @service_result_target
          @page.get_battery_level(on_result: lambda do |*level_out|
            next unless current_service_request?(request_token)

            level, level_error = level_out
            next show_service_result(level_error, title: "Battery failed", target: result_target) if service_error?(level_error)

            @page.get_battery_state(on_result: lambda do |*state_out|
              next unless current_service_request?(request_token)

              state, state_error = state_out
              next show_service_result(state_error, title: "Battery failed", target: result_target) if service_error?(state_error)

              @page.is_in_battery_save_mode(on_result: lambda do |*save_out|
                next unless current_service_request?(request_token)

                save_mode, save_error = save_out
                next show_service_result(save_error, title: "Battery failed", target: result_target) if service_error?(save_error)

                level_label = level.nil? ? "Unknown" : "#{level}%"
                state_label = state.to_s.empty? ? "unknown" : state.to_s.upcase
                saver_label = save_mode ? "ON" : "OFF"
                show_service_result(
                  "Battery level: #{level_label}\nBattery state: #{state_label}\nBattery saver: #{saver_label}",
                  title: "Battery", target: result_target
                )
              end)
            end)
          end)
        end

        def secure_storage
          reuse_service(:secure_storage, "ruflet_rails_secure_storage")
        end

        def permissions
          reuse_service(:permission_handler, "ruflet_rails_permissions")
        end

        # Build an `on_result` callback that reports the outcome in a native
        # dialog. Native results arrive as `(value, error)`; a variadic lambda
        # copes with methods that pass only a value.
        def report(label, show_result: false)
          request_token = @service_request_token
          result_target = @service_result_target
          lambda do |*out|
            next unless current_service_request?(request_token)

            value, error = out
            if service_error?(error)
              show_service_result(error, title: "#{label} failed", target: result_target)
            elsif show_result
              show_service_result(format_service_value(value), title: label, target: result_target)
            else
              show_service_result("Completed successfully.", title: label, target: result_target)
            end
          end
        end

        def service_error?(error)
          !error.nil? && !error.to_s.empty?
        end

        def format_service_value(value)
          value = value.data if value.respond_to?(:data)
          case value
          when nil then "(none)"
          when Hash then value.map { |k, v| "#{k}: #{v}" }.join(", ")
          when Array then value.map(&:to_s).join(", ")
          else value.to_s.empty? ? "(empty)" : value.to_s
          end
        end

        def clamp_unit(value, default)
          return default if value.nil? || value.to_s.strip.empty?

          value.to_f.clamp(0.0, 1.0)
        end

        def show_service_result(message, title: "Service result", target: nil)
          message = message.to_s
          return if message.empty?

          # A targeted result updates its status control in place — the Studio
          # model. Crucially, when a target was requested but the control is
          # gone (the user navigated away before this async result arrived), we
          # drop it silently. Falling back to the dialog here is exactly what
          # makes a stray "…failed/expired" alert pop up on an unrelated screen.
          if target
            control = @page.get_control(target.to_s)
            @page.update(control, value: message) if control
            return
          end

          ensure_service_dialog
          if @service_dialog.wire_id
            @page.update(@service_dialog_title, value: title.to_s)
            @page.update(@service_dialog_content, value: message)
            # Ruflet Studio mounts one dialog and toggles its open property.
            # Keeping the same control prevents delayed responses from stacking.
            @page.update(@service_dialog, open: true)
          else
            @service_dialog_title.props["value"] = title.to_s
            @service_dialog_content.props["value"] = message
            @page.show_dialog(@service_dialog)
          end
        rescue StandardError
          nil
        end

        def close_service_dialog
          return unless @service_dialog

          @service_request_token += 1
          @page.update(@service_dialog, open: false)
        rescue StandardError
          nil
        end

        def ensure_service_dialog
          return @service_dialog if @service_dialog

          @service_dialog_title = text("")
          @service_dialog_content = text("", selectable: true)
          @service_dialog = alert_dialog(
            adaptive: true,
            modal: true,
            scrollable: true,
            open: false,
            title: @service_dialog_title,
            content: @service_dialog_content,
            actions: [
              text_button(
                content: text("Close"),
                on_click: ->(_event) { close_service_dialog }
              )
            ],
            on_dismiss: ->(_event) { close_service_dialog }
          )
        end

        def current_service_request?(token)
          token == @service_request_token
        end

        # In-place re-render (an action or form submit on the current screen).
        # Only the parts that actually changed are patched: re-sending an
        # identical app bar / nav / FAB makes the client rebuild that widget
        # and flicker, so we diff each against the last render first.
        def rerender(screen, response)
          # Re-rendering a screen means parsing its markup and rebuilding the
          # whole control tree, which costs more than the ERB render that
          # produced it. When an action leaves the screen byte-identical —
          # a tap that changed nothing the screen shows — none of that work can
          # change anything, and neither can the diff it feeds.
          markup = response.body.to_s
          return if screen.view&.wire_id && screen.markup && screen.markup == markup

          screen.markup = markup
          result = render_result(screen, response)
          mount_services(result)
          unless screen.view&.wire_id
            screen.view = build_view(screen, result)
            remember_chrome(screen, result)
            flush
            return
          end

          new_body = body_for(result)
          patch = {}
          appbar = appbar_for(screen, result)
          patch[:appbar] = appbar if chrome_changed?(screen, :appbar_sig, appbar)
          patch[:floating_action_button] = result.fab if chrome_changed?(screen, :fab_sig, result.fab)
          patch[:navigation_bar] = result.bottom_nav if chrome_changed?(screen, :nav_sig, result.bottom_nav)

          # Most re-renders change a value, not a shape: a counter ticks, a
          # status line fills in, a list item flips. Replacing the whole body
          # would re-send every control on the screen to move one string, and
          # would make the client rebuild the subtree (losing scroll position
          # with it). When the new tree has the same shape as the mounted one,
          # send only the props that actually differ.
          updates = ControlDiff.new(screen.body, new_body).updates if screen.body
          if updates
            @page.update(screen.view, **patch) unless patch.empty?
            updates.each { |control, props| @page.update(control, **props) }
          else
            screen.body = new_body
            @page.update(screen.view, controls: [new_body], **patch)
          end
        end

        # Record the current chrome signatures so the next in-place re-render
        # can tell what changed.
        def remember_chrome(screen, result)
          screen.appbar_sig = chrome_sig(appbar_for(screen, result))
          screen.fab_sig = chrome_sig(result.fab)
          screen.nav_sig = chrome_sig(result.bottom_nav)
        end

        def chrome_changed?(screen, field, control)
          sig = chrome_sig(control)
          return false if screen[field] == sig

          screen[field] = sig
          true
        end

        def chrome_sig(control)
          control ? JSON.generate(control.to_patch) : nil
        rescue StandardError
          control.object_id.to_s
        end

        def render_result(screen, response)
          screen.url = response.url.to_s unless response.url.to_s.empty?
          screen.fields = {}
          body = error_status?(response.status) ? server_error_markup(response) : response.body.to_s
          # Strings sliced from a binary body would go over the wire as
          # msgpack bin (byte arrays on the client); make sure we parse UTF-8.
          body = body.dup.force_encoding(Encoding::UTF_8) if body.encoding == Encoding::ASCII_8BIT
          result = transform(screen, body)
          screen.csrf_token = result.csrf_token
          screen.title = result.title
          if result.controls.empty?
            message = response.status.to_i >= 400 ? "HTTP #{response.status} — #{screen.url}" : "Empty screen"
            result.controls = [container(content: text(message), alignment: { x: 0, y: 0 }, expand: true)]
          end
          result
        end

        def transform(screen, body)
          transformer = Transformer.new(handlers: ScreenHandlers.new(self, screen),
                                        asset_base_url: asset_base_url)
          transformer.transform(body)
        rescue StandardError => e
          transformer.transform(error_markup(screen.url, e))
        end

        # Media is the one thing the client fetches for itself, so it is the one
        # thing that still needs a host. Resolved per render, because the answer
        # depends on the connection this session is running on.
        def asset_base_url
          return nil unless defined?(::Ruflet::Rails.backend_url)

          ::Ruflet::Rails.backend_url
        rescue StandardError
          nil
        end

        # 422 is the Rails convention for re-rendering a form with validation
        # errors — that body is a real screen. Other error statuses carry a
        # Rails error page (dev exception pages are a full web document).
        def error_status?(status)
          status = status.to_i
          status >= 400 && status != 422
        end

        # Surface the error page's title as a compact native screen instead of
        # trying to render the page itself.
        def server_error_markup(response)
          title = response.body.to_s[%r{<title>(.*?)</title>}m, 1].to_s.strip
          title = "Server error" if title.empty?
          <<~HTML
            <column class="p-6 gap-2">
              <h3>HTTP #{response.status}</h3>
              <text class="font-semibold text-red-600">#{ERB::Util.html_escape(title)}</text>
              <text class="text-slate-500">#{ERB::Util.html_escape(response.url)}</text>
              <text class="text-sm text-slate-400">Check the Rails server log for the full trace.</text>
            </column>
          HTML
        end

        def build_view(screen, result)
          args = { route: screen.route }
          appbar = appbar_for(screen, result)
          args[:appbar] = appbar if appbar
          args[:floating_action_button] = result.fab if result.fab
          args[:navigation_bar] = result.bottom_nav if result.bottom_nav
          # Kept so the next in-place re-render can diff against what is
          # actually mounted instead of replacing it.
          screen.body = body_for(result)
          view([screen.body], **args)
        end

        # Screens scroll by default, like a web page. But a screen whose
        # top-level control expands (flex-1 / h-full, e.g. a vertically
        # centered layout) needs the fixed viewport instead: an expanding
        # child inside a scrollable has unbounded height and collapses to an
        # empty body.
        def body_for(result)
          expanding = result.controls.any? { |control| control.respond_to?(:props) && control.props["expand"] }
          props = { expand: true, spacing: 0 }
          props[:scroll] = "auto" unless expanding
          column(result.controls, **props)
        end

        # Declared `<appbar>` wins. A pushed screen without one still gets a
        # titled AppBar so the native back button exists; the root only gets
        # one when the app asked for a title.
        def appbar_for(screen, result)
          return result.appbar if result.appbar

          title = screen.root ? (@title || "") : (result.title || @title || title_from_url(screen.url))
          return nil if title.to_s.strip.empty?

          appbar(title: text(title.to_s))
        end

        def flush
          @page.views = @screens.map(&:view)
          @page.update
        end

        # --- HTTP -----------------------------------------------------------------

        def request(method, url, params: nil, screen: nil)
          headers = {}
          token = screen&.csrf_token || @screens.last&.csrf_token
          headers["X-CSRF-Token"] = token if token && method.to_s.downcase != "get"
          @fetcher.fetch(method, url, params: params, headers: headers)
        rescue StandardError => e
          TemplateSource::Response.new(status: 0, body: error_markup(url, e), url: url)
        end

        def error_markup(url, error)
          <<~HTML
            <column class="p-6 gap-2">
              <h3>Could not load screen</h3>
              <text class="text-slate-500">#{url}</text>
              <text class="text-red-600">#{error.message}</text>
            </column>
          HTML
        end

        # Screens may be declared as paths ("/native") or as full URLs. A path
        # stays a path: the fetcher supplies the host from the live WebSocket
        # connection, so nothing here has to name one. Relative links still
        # resolve against the current screen either way — done by borrowing a
        # placeholder host, since URI.join needs an absolute base, and then
        # dropping it again.
        PATH_RESOLUTION_BASE = "http://ruflet.invalid"

        def absolute_url(url)
          url = url.to_s
          return "" if url.empty?
          return url if URI.parse(url).absolute?

          base = current_url
          return URI.join(base, url).to_s if URI.parse(base).absolute?

          resolved = URI.join("#{PATH_RESOLUTION_BASE}#{base}", url)
          resolved.query ? "#{resolved.path}?#{resolved.query}" : resolved.path
        rescue URI::InvalidURIError, URI::BadURIError
          url
        end

        def current_url
          @screens.last&.url || @start_url
        end

        def title_from_url(url)
          path = URI.parse(url.to_s).path.to_s
          label = path.split("/").reject(&:empty?).last.to_s
          label = "Screen" if label.empty?
          label.tr("_-", " ").split.map(&:capitalize).join(" ")
        rescue URI::InvalidURIError
          "Screen"
        end
      end
    end
  end
end
