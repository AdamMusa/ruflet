# frozen_string_literal: true

require "fileutils"

module Ruflet
  module CLI
    # Startup hooks for the Flutter client: ordered lists that the template
    # entrypoints (lib/main.self.dart and lib/main.server.dart) run just before
    # runApp and after the first frame.
    #
    # The entrypoints declare both lists empty themselves, between
    # CLIENT_BOOTSTRAP_BLOCK_START and CLIENT_BOOTSTRAP_BLOCK_END, so they build
    # with every gem, including released ones that know nothing about hooks.
    #
    # * While no build feature adds a hook, this writes nothing at all, in
    #   build/client or in a client dir the developer owns (RUFLET_CLIENT_DIR,
    #   ./ruflet_client, templates/ruflet_flutter_template).
    # * Once one does, it writes the hooks to lib/ruflet_bootstrap.g.dart,
    #   imports that file in each entrypoint and empties the marked block. Each
    #   build first copies lib/main*.dart from the template again
    #   (refresh_managed_client_template_files), so the next build without
    #   hooks starts from the template's own empty lists, and the generated
    #   file, imported by nothing any more, is removed.
    #
    # A build feature adds hooks by appending the name of a provider method to
    # CLIENT_BOOTSTRAP_HOOK_PROVIDERS. The method receives the build's
    # ruflet.yaml config and returns the hooks that build needs, if any:
    #
    #   def deep_link_bootstrap_hooks(config, platform:, self_contained:)
    #     return [] unless config["deep_links"]
    #
    #     [{ phase: :pre_run_app, import: "package:ruflet/ruflet.dart",
    #        function: "RufletDeepLinkingBootstrap.install" }]
    #   end
    #
    # `function` is a top-level function, or a Class.staticMethod, of the
    # imported library that takes no arguments. Hooks run in provider order,
    # then in the order each provider returns them.
    module ClientBootstrap
      CLIENT_BOOTSTRAP_PATH = File.join("lib", "ruflet_bootstrap.g.dart").freeze
      # The entrypoints that run the hooks. lib/main.dart only calls
      # main.self.dart's main.
      CLIENT_BOOTSTRAP_ENTRYPOINTS = %w[lib/main.self.dart lib/main.server.dart].freeze
      CLIENT_BOOTSTRAP_IMPORT = "import 'ruflet_bootstrap.g.dart';"
      # An import of the generated file, relative or through the package.
      CLIENT_BOOTSTRAP_IMPORT_LINE = %r{\A\s*import\s+(['"])(?:[^'"]*/)?ruflet_bootstrap\.g\.dart\1}
      # ruflet-template pins the same markers in
      # tool/conformance/test_bootstrap_hooks_contract.rb.
      CLIENT_BOOTSTRAP_BLOCK_START = "// --RUFLET_BOOTSTRAP_HOOKS_START--"
      CLIENT_BOOTSTRAP_BLOCK_END = "// --RUFLET_BOOTSTRAP_HOOKS_END--"
      # What the marked block holds once the lists come from the generated file.
      CLIENT_BOOTSTRAP_BLOCK_POINTER = "// This build's hooks are in lib/ruflet_bootstrap.g.dart."
      # Phase => the list the entrypoints read for it.
      CLIENT_BOOTSTRAP_PHASES = {
        pre_run_app: "rufletPreRunAppHooks",
        post_first_frame: "rufletPostFirstFrameHooks"
      }.freeze
      CLIENT_BOOTSTRAP_HOOK_PROVIDERS = [].freeze

      CLIENT_BOOTSTRAP_IMPORT_PATTERN = %r{\A(?:(?:package:)?[A-Za-z0-9_][A-Za-z0-9_./-]*\.dart|dart:[a-z_]+)\z}
      CLIENT_BOOTSTRAP_FUNCTION_PATTERN = /\A[A-Za-z_$][A-Za-z0-9_$]*(?:\.[A-Za-z_$][A-Za-z0-9_$]*)?\z/

      # The start of every file this module writes. A file that does not begin
      # with it is never deleted.
      CLIENT_BOOTSTRAP_SIGNATURE = "// GENERATED FILE. DO NOT EDIT.\n//\n// `ruflet build` writes this file"
      CLIENT_BOOTSTRAP_HEADER = <<~DART
        // GENERATED FILE. DO NOT EDIT.
        //
        // `ruflet build` writes this file only while a build feature adds startup
        // hooks, and imports it from lib/main.self.dart and lib/main.server.dart
        // in place of their own empty lists. They run the hooks in list order:
        //
        // * rufletPreRunAppHooks are awaited one at a time just before runApp, once
        //   the Flutter binding and every extension are initialized.
        // * rufletPostFirstFrameHooks run one at a time after the first frame.
        //
        // A hook that throws is reported through FlutterError.reportError and does
        // not stop the hooks after it or the app. Build features add hooks through
        // Ruflet::CLI::ClientBootstrap in the ruflet gem.
      DART

      private

      # Points the client at the startup hooks this build's features add.
      #
      # With no hooks, and entrypoints that do not import the generated file
      # (every released template), nothing is written or deleted, so the client
      # is exactly what it would be without this module. Returns the generated
      # file's path when the client uses it, otherwise nil.
      def write_client_bootstrap(client_dir, config = {}, platform: nil, self_contained: false)
        hooks = client_bootstrap_hooks(config, platform: platform, self_contained: self_contained)
        # Rendering validates every hook, so a malformed one raises before any
        # file is touched.
        content = render_client_bootstrap(hooks)
        route_client_entrypoints_to_bootstrap(client_dir, hooks.size) unless hooks.empty?

        path = File.join(client_dir, CLIENT_BOOTSTRAP_PATH)
        unless client_bootstrap_imported?(client_dir)
          remove_stale_client_bootstrap(path)
          return nil
        end
        # An entrypoint that imports the file needs it even without hooks, for
        # example one an earlier build pointed at it when no template was
        # available to refresh it from. It then gets both lists empty.
        return path if File.file?(path) && File.binread(path) == content

        FileUtils.mkdir_p(File.dirname(path))
        # Binary mode keeps LF line endings on Windows, matching the template.
        File.binwrite(path, content)
        path
      end

      def client_bootstrap_hooks(config, platform:, self_contained:)
        client_bootstrap_hook_providers.flat_map do |provider|
          hooks = send(provider, config, platform: platform, self_contained: self_contained)
          hooks.is_a?(Hash) ? [hooks] : Array(hooks)
        end
      end

      def client_bootstrap_hook_providers
        CLIENT_BOOTSTRAP_HOOK_PROVIDERS
      end

      def route_client_entrypoints_to_bootstrap(client_dir, hook_count)
        unrouted = CLIENT_BOOTSTRAP_ENTRYPOINTS.select do |relative_path|
          path = File.join(client_dir, relative_path)
          File.file?(path) && !route_client_entrypoint_to_bootstrap(path)
        end
        warn_unrouted_client_bootstrap(unrouted, hook_count) unless unrouted.empty?
      end

      # Empties the entrypoint's marked block and imports the generated file
      # instead. Returns false when the entrypoint has neither the block nor the
      # import, so the hooks cannot reach it.
      def route_client_entrypoint_to_bootstrap(path)
        content = read_text_file(path)
        lines = content.lines
        imported = lines.any? { |line| line.match?(CLIENT_BOOTSTRAP_IMPORT_LINE) }
        start = lines.index { |line| line.chomp == CLIENT_BOOTSTRAP_BLOCK_START }
        finish = start && lines.each_index.find { |index| index > start && lines[index].chomp == CLIENT_BOOTSTRAP_BLOCK_END }
        return imported unless finish

        lines[(start + 1)...finish] = ["#{CLIENT_BOOTSTRAP_BLOCK_POINTER}\n"]
        insert_client_bootstrap_import(lines) unless imported
        updated = lines.join
        write_text_file(path, updated) unless updated == content
        true
      end

      # After the last import directive, which may span several lines.
      def insert_client_bootstrap_import(lines)
        last_import = lines.rindex { |line| line.start_with?("import ") }
        unless last_import
          lines.unshift("#{CLIENT_BOOTSTRAP_IMPORT}\n")
          return
        end

        directive_end = (last_import...lines.length).find { |index| lines[index].rstrip.end_with?(";") } || last_import
        lines.insert(directive_end + 1, "#{CLIENT_BOOTSTRAP_IMPORT}\n")
      end

      # Whether any Dart file under lib/ imports the generated file. It only
      # reads, and reads bytes, so a file in a client dir the developer owns
      # that is not valid UTF-8, or not readable, cannot fail a build.
      def client_bootstrap_imported?(client_dir)
        generated = File.expand_path(File.join(client_dir, CLIENT_BOOTSTRAP_PATH))
        Dir.glob(File.join(client_dir, "lib", "**", "*.dart")).any? do |dart_file|
          next false if File.expand_path(dart_file) == generated || !File.file?(dart_file)

          source = File.binread(dart_file)
          next false unless source.include?("ruflet_bootstrap.g.dart")

          source.force_encoding(Encoding::UTF_8).scrub.each_line.any? { |line| line.match?(CLIENT_BOOTSTRAP_IMPORT_LINE) }
        rescue SystemCallError
          false
        end
      end

      # A generated file nothing imports any more, left by a build with hooks
      # whose entrypoints have since been refreshed from the template. A file
      # this module did not write is never touched.
      def remove_stale_client_bootstrap(path)
        return unless File.file?(path)
        return unless File.binread(path, CLIENT_BOOTSTRAP_SIGNATURE.bytesize) == CLIENT_BOOTSTRAP_SIGNATURE

        File.delete(path)
      end

      def warn_unrouted_client_bootstrap(entrypoints, hook_count)
        hooks = "#{hook_count} startup hook#{'s' unless hook_count == 1}"
        verb, pronoun = entrypoints.size == 1 ? %w[has it] : %w[have them]
        warn "warning: #{entrypoints.join(' and ')} #{verb} no #{CLIENT_BOOTSTRAP_BLOCK_START} block, " \
             "so the #{hooks} this build adds will not run from #{pronoun}. " \
             "Update the Flutter client from the current ruflet-template."
      end

      def render_client_bootstrap(hooks)
        aliases = {}
        entries = CLIENT_BOOTSTRAP_PHASES.keys.to_h { |phase| [phase, []] }
        Array(hooks).each do |hook|
          phase, import, function = client_bootstrap_hook_parts(hook)
          library_alias = (aliases[import] ||= "bootstrap_#{aliases.size + 1}")
          entries[phase] << "#{library_alias}.#{function}"
        end

        out = +CLIENT_BOOTSTRAP_HEADER
        out << "\nimport 'dart:async';\n"
        unless aliases.empty?
          out << "\n"
          aliases.each { |import, library_alias| out << "import '#{import}' as #{library_alias};\n" }
        end
        # The same function type as the entrypoints' RufletBootstrapHook, which
        # they keep declaring outside the marked block.
        CLIENT_BOOTSTRAP_PHASES.each do |phase, list_name|
          out << "\n"
          if entries[phase].empty?
            out << "const #{list_name} = <FutureOr<void> Function()>[];\n"
          else
            out << "const #{list_name} = <FutureOr<void> Function()>[\n"
            entries[phase].each { |entry| out << "  #{entry},\n" }
            out << "];\n"
          end
        end
        out
      end

      def client_bootstrap_hook_parts(hook)
        raise ArgumentError, "bootstrap hook must be a Hash: #{hook.inspect}" unless hook.is_a?(Hash)

        phase = (hook[:phase] || hook["phase"]).to_s.to_sym
        import = (hook[:import] || hook["import"]).to_s
        function = (hook[:function] || hook["function"]).to_s
        unless CLIENT_BOOTSTRAP_PHASES.key?(phase)
          raise ArgumentError, "unknown bootstrap hook phase #{phase.inspect}; " \
                               "expected one of #{CLIENT_BOOTSTRAP_PHASES.keys.join(', ')}"
        end
        unless import.match?(CLIENT_BOOTSTRAP_IMPORT_PATTERN)
          raise ArgumentError, "invalid bootstrap hook import #{import.inspect}"
        end
        unless function.match?(CLIENT_BOOTSTRAP_FUNCTION_PATTERN)
          raise ArgumentError, "invalid bootstrap hook function #{function.inspect}"
        end

        [phase, import, function]
      end
    end
  end
end
