# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Selects the client's Flutter extension packages: the bundled ones the
        # project and its services need, and external git or path packages.
        module Extensions
          CLIENT_EXTENSION_MAP = {
            "ads" => { package: "ruflet_ads", alias: "ruflet_ads" },
            "audio" => { package: "ruflet_audio", alias: "ruflet_audio" },
            "audio_recorder" => { package: "ruflet_audio_recorder", alias: "ruflet_audio_recorder" },
            "camera" => { package: "ruflet_camera", alias: "ruflet_camera" },
            "charts" => { package: "ruflet_charts", alias: "ruflet_charts" },
            "code_editor" => { package: "ruflet_code_editor", alias: "ruflet_code_editor" },
            "color_pickers" => { package: "ruflet_color_pickers", alias: "ruflet_color_picker" },
            "datatable2" => { package: "ruflet_datatable2", alias: "ruflet_datatable2" },
            "flashlight" => { package: "ruflet_flashlight", alias: "ruflet_flashlight" },
            "geolocator" => { package: "ruflet_geolocator", alias: "ruflet_geolocator" },
            "local_auth" => { package: "ruflet_local_auth", alias: "ruflet_local_auth" },
            "lottie" => { package: "ruflet_lottie", alias: "ruflet_lottie" },
            "map" => { package: "ruflet_map", alias: "ruflet_map" },
            "permission_handler" => { package: "ruflet_permission_handler", alias: "ruflet_permission_handler" },
            "qrcode_scanner" => { package: "ruflet_qrcode_scanner", alias: "ruflet_qrcode_scanner" },
            "rive" => { package: "ruflet_rive", alias: "ruflet_rive" },
            "secure_storage" => { package: "ruflet_secure_storage", alias: "ruflet_secure_storage" },
            "spinkit" => { package: "ruflet_spinkit", alias: "ruflet_spinkit" },
            "video" => { package: "ruflet_video", alias: "ruflet_video" },
            "webview" => { package: "ruflet_webview", alias: "ruflet_webview" }
          }.freeze

          # local_auth shows its Android prompt with androidx.biometric, which
          # requires the host activity to be a FragmentActivity.
          FRAGMENT_ACTIVITY_EXTENSIONS = %w[local_auth].freeze
          MANAGED_EXTENSION_STATE_PATH = File.join(".ruflet", "extension_dependencies.json")

          private

          def apply_service_extension_config(client_dir, config = {}, self_contained: @ruflet_self_contained_build)
            extension_keys = configured_extension_keys(config)
            flutter_extension_keys = extension_keys
            extension_packages = flutter_extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:package) }.uniq
            extension_aliases = flutter_extension_keys.filter_map { |key| CLIENT_EXTENSION_MAP[key]&.fetch(:alias) }.uniq

            configured_external = external_extension_entries(config)
            external = configured_external
            previous_external_names = managed_external_extension_names(client_dir)
            discovered_external_names = discover_registered_external_extension_names(client_dir)
            removable_external_names = (
              previous_external_names + discovered_external_names + configured_external.map { |entry| entry[:name] }
            ).uniq

            pubspec_path = File.join(client_dir, "pubspec.yaml")
            if File.file?(pubspec_path)
              sync_client_extension_dependencies(pubspec_path, extension_packages)
              prune_client_pubspec(pubspec_path, extension_packages)
              sync_external_extension_dependencies(
                pubspec_path,
                external,
                managed_names: removable_external_names
              )
            end
            sync_client_package_directories(client_dir, extension_packages)
            client_entrypoint_paths(client_dir).each do |entrypoint|
              next unless File.file?(entrypoint)

              sync_client_main_extensions(entrypoint, extension_aliases)
              prune_client_main(entrypoint, extension_aliases)
              prune_external_extension_registrations(
                entrypoint,
                removable_external_names - external.map { |entry| entry[:name] }
              )
              sync_external_extension_registrations(entrypoint, external)
            end
            write_managed_external_extension_names(client_dir, external.map { |entry| entry[:name] })
            apply_android_activity_base(client_dir, extension_keys)
            @ruflet_selected_flutter_extension_packages = extension_packages
            @ruflet_selected_external_extension_packages = external.map { |entry| entry[:name] }
            @ruflet_managed_external_extension_packages = removable_external_names
            @ruflet_extension_selection_applied = true
            extension_keys
          end

          # An extension may name a package the template does not bundle, declared
          # with the source to fetch it from:
          #
          #   extensions:
          #     - charts
          #     - my_package:
          #         git:
          #           url: https://github.com/owner/my_package
          #           ref: main
          #
          # `branch` is accepted for `ref`, and `path` for a local checkout.
          def external_extension_entries(config)
            Array(config["extensions"]).filter_map do |entry|
              next unless entry.is_a?(Hash)
              next unless entry.size == 1

              name, source = entry.first
              package = name.to_s.strip
              next if package.empty?

              dependency = external_extension_dependency(source)
              next unless dependency

              { name: package, dependency: dependency }
            end
          end

          def external_extension_dependency(source)
            return nil unless source.is_a?(Hash)

            normalized = source.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
            git = normalized["git"] || normalized["github"] || normalized["repository"]
            git = normalized if git.nil? && normalized.key?("url")

            if git.is_a?(String)
              return { "git" => git }
            elsif git.is_a?(Hash)
              git = git.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
              url = git["url"].to_s.strip
              return nil if url.empty?

              spec = { "url" => url }
              ref = (git["ref"] || git["branch"] || git["tag"]).to_s.strip
              spec["ref"] = ref unless ref.empty?
              path = git["path"].to_s.strip
              spec["path"] = path unless path.empty?
              return { "git" => spec }
            end

            local = normalized["path"]
            return { "path" => local.to_s } if local.is_a?(String) && !local.to_s.strip.empty?

            nil
          end

          def sync_external_extension_dependencies(pubspec_path, entries, managed_names: [])
            data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
            dependencies = (data["dependencies"] || {}).dup
            selected_names = entries.map { |entry| entry[:name] }
            Array(managed_names).each do |name|
              dependencies.delete(name) unless selected_names.include?(name)
            end
            entries.each { |entry| dependencies[entry[:name]] = entry[:dependency] }
            data["dependencies"] = dependencies
            write_pubspec_yaml(pubspec_path, data)
            build_note("Added #{selected_names.join(', ')} from the extension configuration") unless selected_names.empty?
          end

          def managed_extension_state_path(client_dir)
            File.join(client_dir, MANAGED_EXTENSION_STATE_PATH)
          end

          def managed_external_extension_names(client_dir)
            path = managed_extension_state_path(client_dir)
            return [] unless File.file?(path)

            data = JSON.parse(read_text_file(path))
            Array(data["external_packages"]).map(&:to_s).reject(&:empty?).uniq
          rescue StandardError
            []
          end

          def write_managed_external_extension_names(client_dir, names)
            path = managed_extension_state_path(client_dir)
            FileUtils.mkdir_p(File.dirname(path))
            write_text_file(path, JSON.pretty_generate("external_packages" => Array(names).map(&:to_s).uniq.sort))
          end

          def discover_registered_external_extension_names(client_dir)
            known_packages = CLIENT_EXTENSION_MAP.values.map { |entry| entry.fetch(:package) }.uniq
            client_entrypoint_paths(client_dir).flat_map do |path|
              next [] unless File.file?(path)

              content = read_text_file(path)
              content.scan(%r{import 'package:([^/]+)/[^']+'\s+as\s+([A-Za-z0-9_]+);}).filter_map do |package, import_alias|
                next if known_packages.include?(package)
                next unless content.match?(/^\s*#{Regexp.escape(import_alias)}\.Extension\(\),\s*$/)

                package
              end
            end.uniq
          end

          def prune_external_extension_registrations(path, package_names)
            return if package_names.empty?

            content = read_text_file(path)
            original = content.dup
            package_names.each do |package|
              escaped = Regexp.escape(package)
              aliases = content.scan(%r{^import 'package:#{escaped}/[^']+'\s+as\s+([A-Za-z0-9_]+);\s*$}).flatten
              content.gsub!(%r{^import 'package:#{escaped}/[^']+'\s+as\s+[A-Za-z0-9_]+;\s*\n}, "")
              aliases.each do |import_alias|
                content.gsub!(/^\s*#{Regexp.escape(import_alias)}\.Extension\(\),\s*\n/, "")
              end
            end
            write_text_file(path, content) unless content == original
          end

          def validate_flutter_extension_selection(client_dir)
            selected = Array(@ruflet_selected_flutter_extension_packages)
            selected_external = Array(@ruflet_selected_external_extension_packages)
            pubspec_path = File.join(client_dir, "pubspec.yaml")
            return true unless File.file?(pubspec_path)

            data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
            dependencies = data["dependencies"].is_a?(Hash) ? data["dependencies"].keys.map(&:to_s) : []
            optional = CLIENT_EXTENSION_MAP.values.map { |entry| entry.fetch(:package) }.uniq
            unexpected = (dependencies & optional) - selected
            missing = selected - dependencies
            managed_external = Array(@ruflet_managed_external_extension_packages)
            unexpected_external = (dependencies & managed_external) - selected_external
            errors = []
            errors << "unused Flutter extensions remain: #{unexpected.join(', ')}" unless unexpected.empty?
            errors << "selected Flutter extensions are missing: #{missing.join(', ')}" unless missing.empty?
            errors << "unused external Flutter extensions remain: #{unexpected_external.join(', ')}" unless unexpected_external.empty?
            return true if errors.empty?

            errors.each { |message| warn "build config error: #{message}" }
            false
          rescue StandardError => e
            warn "build config error: could not verify Flutter extension pruning: #{e.message}"
            false
          end

          # Ruflet extension packages expose an Extension class from a library named
          # after the package, so the import and registration can be derived.
          def sync_external_extension_registrations(path, entries)
            return if entries.empty?

            content = read_text_file(path)
            original = content.dup

            entries.each do |entry|
              name = entry[:name]
              import_line = %(import 'package:#{name}/#{name}.dart' as #{name};\n)
              extension_line = "    #{name}.Extension(),\n"

              content = insert_missing_import(content, import_line) unless content.include?("package:#{name}/#{name}.dart")
              content = insert_missing_extension(content, extension_line) unless content.match?(/^\s*#{Regexp.escape(name)}\.Extension\(\),/)
            end

            write_text_file(path, content) unless content == original
          end

          # The template's MainActivity extends FlutterActivity. Switch it to
          # FlutterFragmentActivity while an extension that needs one (local_auth)
          # is selected, and back once none is, so the activity always matches the
          # build's extensions. An activity that extends anything else is left alone.
          def apply_android_activity_base(client_dir, extension_keys)
            fragment = Array(extension_keys).any? { |key| FRAGMENT_ACTIVITY_EXTENSIONS.include?(key) }
            from, to = fragment ? %w[FlutterActivity FlutterFragmentActivity] : %w[FlutterFragmentActivity FlutterActivity]

            android_main_activity_paths(client_dir).each do |path|
              content = read_text_file(path)
              updated = content.sub(/^((?:public\s+)?class MainActivity\s*(?::|extends)\s*)#{from}\b/, "\\1#{to}")
              next if updated == content

              updated = updated.sub(/^import io\.flutter\.embedding\.android\.#{from}(;?)$/, "import io.flutter.embedding.android.#{to}\\1")
              write_text_file(path, updated)
            end
          end

          def android_main_activity_paths(client_dir)
            Dir.glob(File.join(client_dir, "android", "app", "src", "main", "{kotlin,java}", "**", "MainActivity.{kt,java}")).sort
          end

          def normalize_extension_key(value)
            key = value.to_s.strip.downcase
            return nil if key.empty?

            key.tr!("-", "_")
            key.gsub!(/\A(flet_)+/, "") # Compatibility for existing application configuration.
            key.gsub!(/\A(ruflet_)+/, "")
            key.gsub!(/\Aservice_/, "")
            key
          end

          def prune_client_pubspec(path, selected_packages)
            data = YAML.safe_load(read_text_file(path), aliases: true) || {}
            deps = (data["dependencies"] || {}).dup
            optional_packages = CLIENT_EXTENSION_MAP.values.map { |entry| entry.fetch(:package) }.uniq

            deps.keys.each do |name|
              next unless optional_packages.include?(name)
              next if selected_packages.include?(name)

              deps.delete(name)
            end

            data["dependencies"] = deps
            write_pubspec_yaml(path, data)
          end

          def sync_client_package_directories(client_dir, selected_packages)
            packages_root = File.join(client_dir, "ruflet_packages")

            kept_packages = (["ruflet"] + selected_packages).uniq
            template_root =
              if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
                Ruflet::CLI.send(:resolve_ruflet_client_template_root)
              end
            template_packages_root = template_root && File.join(template_root, "ruflet_packages")

            # These are disposable client sources, not application files. Refresh
            # even existing packages so a rebuild cannot keep an older engine fork.
            kept_packages.each do |package_name|
              destination = File.join(packages_root, package_name)
              next unless template_packages_root

              source = File.join(template_packages_root, package_name)
              next unless Dir.exist?(source)
              next if File.expand_path(source) == File.expand_path(destination)

              FileUtils.rm_rf(destination) if File.exist?(destination)
              Ruflet::CLI.send(:copy_client_template_entry, template_packages_root, packages_root, package_name)
            end

            return unless Dir.exist?(packages_root)

            Dir.children(packages_root).each do |entry|
              path = File.join(packages_root, entry)
              next unless Dir.exist?(path)
              next if kept_packages.include?(entry)

              FileUtils.rm_rf(path)
            end
          end

          def sync_client_extension_dependencies(path, selected_packages)
            template_deps = template_client_pubspec_dependencies
            return if template_deps.empty?

            data = YAML.safe_load(read_text_file(path), aliases: true) || {}
            deps = (data["dependencies"] || {}).dup
            deps.delete_if { |name, _| name == "flet" || name.start_with?("flet_") }
            (["ruflet"] + selected_packages).each do |package_name|
              deps[package_name] = template_deps[package_name] if template_deps.key?(package_name)
            end

            data["dependencies"] = deps
            write_pubspec_yaml(path, data)
          end

          # Check Pub's actual result, including transitive local forks. Merely
          # declaring a path dependency is insufficient: an override can replace it.
          def validate_local_ruflet_packages(client_dir)
            config_path = File.join(client_dir, ".dart_tool", "package_config.json")
            resolved = JSON.parse(File.read(config_path)).fetch("packages")
            legacy = resolved.map { |entry| entry.fetch("name") }.select { |name| name == "flet" || name.start_with?("flet_") }
            raise "legacy Flet packages resolved: #{legacy.join(', ')}" unless legacy.empty?

            expected = (["ruflet"] + Array(@ruflet_selected_flutter_extension_packages)).to_h do |name|
              [name, File.join(client_dir, "ruflet_packages", name)]
            end
            # The core/extension manifests also select local decoupled vendor forks.
            queue = expected.values.dup
            until queue.empty?
              root = queue.shift
              manifest = YAML.safe_load(File.read(File.join(root, "pubspec.yaml")), aliases: true)
              (manifest["dependencies"] || {}).each do |name, dependency|
                next unless dependency.is_a?(Hash) && dependency["path"]
                next if expected.key?(name)

                local = File.expand_path(dependency.fetch("path"), root)
                expected[name] = local
                queue << local
              end
            end
            base = file_uri_for(File.expand_path(config_path))
            expected.each do |name, root|
              entry = resolved.find { |package| package["name"] == name }
              raise "missing local package #{name}" unless entry

              uri = URI.join(base, entry.fetch("rootUri"))
              actual = path_from_file_uri(uri)
              unless uri.scheme == "file" && File.realpath(actual) == File.realpath(root)
                raise "#{name} must resolve to the bundled Ruflet source at #{root}, got #{uri}"
              end
            end
            build_note("Verified #{expected.length} local Ruflet engine, extension and vendor packages")
            true
          rescue StandardError => e
            warn "build config error: local Ruflet package verification failed: #{e.message}"
            false
          end

          def template_client_pubspec_dependencies
            template_root =
              if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
                Ruflet::CLI.send(:resolve_ruflet_client_template_root)
              end
            return {} unless template_root

            pubspec_path = File.join(template_root, "pubspec.yaml")
            return {} unless File.file?(pubspec_path)

            data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
            deps = data["dependencies"]
            deps.is_a?(Hash) ? deps : {}
          rescue StandardError
            {}
          end

          def sync_client_main_extensions(path, selected_aliases)
            return if selected_aliases.empty?

            template_path = template_client_entrypoint_path(File.basename(path))
            return unless template_path

            content = read_text_file(path)
            template = read_text_file(template_path)

            selected_aliases.each do |extension_alias|
              import_line = template.lines.find { |line| line.match?(/\sas #{Regexp.escape(extension_alias)};\s*\z/) }
              extension_line = template.lines.find do |line|
                line.match?(/^\s*#{Regexp.escape(extension_alias)}\.[A-Za-z0-9_]+\(\),\s*$/)
              end

              content = insert_missing_import(content, import_line) if import_line && !content.include?(import_line)
              content = insert_missing_extension(content, extension_line) if extension_line && !content.include?(extension_line)
            end

            write_text_file(path, content)
          end

          def template_client_entrypoint_path(name)
            template_root =
              if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
                Ruflet::CLI.send(:resolve_ruflet_client_template_root)
              end
            return nil unless template_root

            path = File.join(template_root, "lib", name)
            File.file?(path) ? path : nil
          end

          def insert_missing_import(content, import_line)
            lines = content.lines
            last_import_index = lines.rindex { |line| line.start_with?("import ") }
            if last_import_index
              lines.insert(last_import_index + 1, import_line)
            else
              lines.unshift(import_line)
            end
            lines.join
          end

          def insert_missing_extension(content, extension_line)
            lines = content.lines
            marker_index = lines.index { |line| line.include?("// --FAT_CLIENT_START--") }
            if marker_index
              lines.insert(marker_index, extension_line)
            else
              list_index = lines.index { |line| line.include?("final extensions = <RufletExtension>[") }
              lines.insert(list_index ? list_index + 1 : lines.length, extension_line)
            end
            lines.join
          end

          def prune_client_main(path, selected_aliases)
            content = read_text_file(path)
            alias_to_package = {}
            optional_aliases = CLIENT_EXTENSION_MAP.values.map { |entry| entry.fetch(:alias) }.uniq

            content.scan(%r{^import 'package:([^/]+)/[^']+'\s+as ([a-zA-Z0-9_]+);$}m) do |package_name, import_alias|
              alias_to_package[import_alias] = package_name
            end
            content.scan(%r{^import '([^']+)'\s+as ([a-zA-Z0-9_]+);$}m) do |_source, import_alias|
              alias_to_package[import_alias] = :local if optional_aliases.include?(import_alias)
            end

            content = content.gsub(%r{^import 'package:([^/]+)/[^']+'\s+as ([a-zA-Z0-9_]+);\n}m) do |match|
              package_name = Regexp.last_match(1)
              import_alias = Regexp.last_match(2)
              if !optional_aliases.include?(import_alias) || selected_aliases.include?(import_alias)
                match
              else
                ""
              end
            end
            content = content.gsub(%r{^import '([^']+)'\s+as ([a-zA-Z0-9_]+);\n}m) do |match|
              import_alias = Regexp.last_match(2)
              if !optional_aliases.include?(import_alias) || selected_aliases.include?(import_alias)
                match
              else
                ""
              end
            end

            content = content.gsub(/^(\s*)([a-zA-Z0-9_]+)\.[A-Za-z0-9_]+\(\),\s*$/) do |match|
              extension_alias = Regexp.last_match(2)
              package_name = alias_to_package[extension_alias]
              if package_name.nil? || !optional_aliases.include?(extension_alias) || selected_aliases.include?(extension_alias)
                match
              else
                ""
              end
            end

            write_text_file(path, content)
          end
        end
      end
    end
  end
end
