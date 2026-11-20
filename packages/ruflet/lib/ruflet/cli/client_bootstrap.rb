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
    # * While no build feature adds a hook, this writes, edits and deletes
    #   nothing, in build/client or in a client dir the developer owns
    #   (RUFLET_CLIENT_DIR, ./ruflet_client, templates/ruflet_flutter_template).
    #   It only looks for a lib/ruflet_bootstrap.g.dart that starts with
    #   CLIENT_BOOTSTRAP_SIGNATURE, which only a build with hooks writes.
    # * Once a feature adds hooks, it writes them to lib/ruflet_bootstrap.g.dart,
    #   imports that file in each entrypoint and empties the marked block. Each
    #   build first copies lib/main*.dart from the template again
    #   (refresh_managed_client_template_files), so the next build without
    #   hooks starts from the template's own empty lists, and the generated
    #   file, which no directive under lib/ names any more, is removed.
    # * A lib/ruflet_bootstrap.g.dart that does not start with the signature
    #   is the developer's own: it is never overwritten or deleted. A build
    #   with hooks then warns and leaves the file and the entrypoints alone.
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
      # The URI of an import directive, in either quote style, also when it
      # sits on the line after `import`. Decides whether routing an entrypoint
      # still has to add the import.
      CLIENT_BOOTSTRAP_IMPORT_URI = /^[ \t]*import\s+(['"])([^'"\r\n]*)\1/
      # Every directive that names another file: import, export or part (not
      # `part of`), up to its semicolon, and every URI in it, a conditional
      # import's alternatives included. A directive may start a line or follow
      # another directive or a block comment on its line. Decides whether the
      # generated file must stay, so text that only looks like a directive
      # after a semicolon (in a comment, say) keeps it too, which is safe. The
      # same two patterns as DIRECTIVE and URI_LITERAL in ruflet-template's
      # tool/conformance/test_bootstrap_hooks_contract.rb.
      CLIENT_BOOTSTRAP_DIRECTIVE = /(?:^|(?<=;)|(?<=\*\/))[ \t]*(import|export|part)(?![A-Za-z0-9_$])(?![ \t]+of\b)([^;]*);/
      CLIENT_BOOTSTRAP_URI_LITERAL = /(['"])([^'"\n]*)\1/
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
      # with it is never overwritten or deleted.
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
      # Without hooks it changes nothing unless the client holds a generated
      # file from an earlier build with hooks: that file is kept in step (both
      # lists empty) while a directive under lib/ names it, and removed once
      # none does. Returns the generated file's path when the client uses it,
      # otherwise nil.
      def write_client_bootstrap(client_dir, config = {}, platform: nil, self_contained: false)
        hooks = client_bootstrap_hooks(config, platform: platform, self_contained: self_contained)
        # Rendering validates every hook, so a malformed one raises before any
        # file is touched.
        content = render_client_bootstrap(hooks)
        path = File.join(client_dir, CLIENT_BOOTSTRAP_PATH)
        existing = client_bootstrap_file(path)

        if hooks.empty?
          # Every build today: no generated file, nothing to do.
          return nil unless existing == :generated
        elsif existing == :foreign
          warn_foreign_client_bootstrap(hooks.size)
          return nil
        else
          route_client_entrypoints_to_bootstrap(client_dir, hooks.size)
        end

        unless client_bootstrap_referenced?(client_dir)
          File.delete(path) if existing == :generated
          return nil
        end
        return path if existing == :generated && File.binread(path) == content

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

      # What is at lib/ruflet_bootstrap.g.dart: nothing (:absent), a file this
      # module wrote (:generated), or anything else (:foreign), such as the
      # developer's own file, a directory, a symlink or a file that cannot be
      # read.
      def client_bootstrap_file(path)
        return :absent unless File.exist?(path) || File.symlink?(path)
        return :foreign if File.symlink?(path) || !File.file?(path)

        File.binread(path, CLIENT_BOOTSTRAP_SIGNATURE.bytesize) == CLIENT_BOOTSTRAP_SIGNATURE ? :generated : :foreign
      rescue SystemCallError
        :foreign
      end

      def route_client_entrypoints_to_bootstrap(client_dir, hook_count)
        package_name = client_package_name(client_dir)
        unrouted = CLIENT_BOOTSTRAP_ENTRYPOINTS.select do |relative_path|
          path = File.join(client_dir, relative_path)
          File.file?(path) && !route_client_entrypoint_to_bootstrap(path, relative_path, package_name)
        end
        warn_unrouted_client_bootstrap(unrouted, hook_count) unless unrouted.empty?
      end

      # Empties the entrypoint's marked block and imports the generated file
      # instead. Returns false when the entrypoint has neither the block nor the
      # import, so the hooks cannot reach it.
      #
      # It edits bytes, so an entrypoint that is not valid UTF-8 is routed too
      # and keeps every byte outside the lines this replaces or adds.
      def route_client_entrypoint_to_bootstrap(path, relative_path, package_name)
        content = File.binread(path)
        imported = client_bootstrap_import_in?(client_bootstrap_text(content), relative_path, package_name)
        lines = content.lines
        start = lines.index { |line| line.chomp == CLIENT_BOOTSTRAP_BLOCK_START }
        finish = start && lines.each_index.find { |index| index > start && lines[index].chomp == CLIENT_BOOTSTRAP_BLOCK_END }
        return imported unless finish

        # The lines this adds end the way the marker line does, so a CRLF
        # entrypoint stays CRLF.
        newline = lines[start].end_with?("\r\n") ? "\r\n" : "\n"
        lines[(start + 1)...finish] = ["#{CLIENT_BOOTSTRAP_BLOCK_POINTER}#{newline}".b]
        insert_client_bootstrap_import(lines, newline) unless imported
        updated = lines.join
        # Binary mode also keeps the line endings as they are on Windows.
        File.binwrite(path, updated) unless updated == content
        true
      end

      # After the last import directive, which may span several lines and end
      # in a // comment.
      def insert_client_bootstrap_import(lines, newline)
        import = "#{CLIENT_BOOTSTRAP_IMPORT}#{newline}".b
        last_import = lines.rindex { |line| line.match?(/\Aimport\s/) }
        unless last_import
          lines.unshift(import)
          return
        end

        directive_end = (last_import...lines.length).find { |index| lines[index].match?(%r{;[ \t]*(?://.*)?\s*\z}) } ||
                        last_import
        lines.insert(directive_end + 1, import)
      end

      # Whether any directive in a Dart file under lib/ names this client's
      # generated file, so the client stops compiling without it. Files and
      # directories that cannot be read are skipped, and a file that is not
      # valid UTF-8 is scanned with its invalid bytes replaced.
      #
      # The client path is the glob's base, never part of its pattern: a
      # developer's client dir may be named "my app [v2]" or "proj{1}", and
      # those characters would otherwise be read as glob syntax and match
      # nothing.
      def client_bootstrap_referenced?(client_dir)
        lib_dir = File.join(client_dir, "lib")
        generated = File.expand_path(File.join(client_dir, CLIENT_BOOTSTRAP_PATH))
        package_name = client_package_name(client_dir)
        Dir.glob("**/*.dart", base: lib_dir).any? do |relative_path|
          dart_file = File.join(lib_dir, relative_path)
          next false if File.expand_path(dart_file) == generated || !File.file?(dart_file)

          source = File.binread(dart_file)
          next false unless source.include?("ruflet_bootstrap.g.dart")

          client_bootstrap_reference_in?(client_bootstrap_text(source), "lib/#{relative_path}", package_name)
        rescue SystemCallError
          false
        end
      end

      # Dart source bytes as UTF-8 text to scan, invalid bytes replaced.
      def client_bootstrap_text(bytes)
        bytes.dup.force_encoding(Encoding::UTF_8).scrub
      end

      # Whether the Dart source at `importer` (relative to the client dir, for
      # example "lib/main.server.dart") imports this client's
      # lib/ruflet_bootstrap.g.dart.
      def client_bootstrap_import_in?(source, importer, package_name)
        source.scan(CLIENT_BOOTSTRAP_IMPORT_URI).any? do |_quote, uri|
          client_bootstrap_uri?(uri, importer, package_name)
        end
      end

      # Whether any import, export or part directive in the Dart source at
      # `importer` names this client's lib/ruflet_bootstrap.g.dart, through
      # any of its URIs, wherever on its line the directive starts
      # (CLIENT_BOOTSTRAP_DIRECTIVE).
      def client_bootstrap_reference_in?(source, importer, package_name)
        source.scan(CLIENT_BOOTSTRAP_DIRECTIVE).any? do |_keyword, rest|
          rest.scan(CLIENT_BOOTSTRAP_URI_LITERAL).any? do |_quote, uri|
            client_bootstrap_uri?(uri, importer, package_name)
          end
        end
      end

      # Only a URI that resolves to this client's lib/ruflet_bootstrap.g.dart:
      # relative to the importing file, or package:<this client's pubspec
      # name>/ruflet_bootstrap.g.dart. Another package's file of the same name
      # is not this one.
      def client_bootstrap_uri?(uri, importer, package_name)
        if uri.start_with?("package:")
          return !package_name.nil? && uri == "package:#{package_name}/ruflet_bootstrap.g.dart"
        end
        # dart:, file:, http: and absolute paths never name the client's file.
        return false if uri.start_with?("/") || uri.match?(/\A[A-Za-z][A-Za-z0-9+.-]*:/)

        segments = importer.split("/")[0...-1]
        uri.split("/").each do |segment|
          case segment
          when "", "." then next
          when ".."
            return false if segments.empty?

            segments.pop
          else
            segments << segment
          end
        end
        segments == %w[lib ruflet_bootstrap.g.dart]
      end

      # The client's package name from its pubspec.yaml, or nil. Every build
      # has already renamed the package to the app's (apply_pubspec_metadata).
      def client_package_name(client_dir)
        source = File.binread(File.join(client_dir, "pubspec.yaml")).force_encoding(Encoding::UTF_8).scrub
        source[/^name:[ \t]*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1[ \t]*(?:#.*)?\r?$/, 2]
      rescue SystemCallError
        nil
      end

      def warn_unrouted_client_bootstrap(entrypoints, hook_count)
        hooks = "#{hook_count} startup hook#{'s' unless hook_count == 1}"
        verb, pronoun = entrypoints.size == 1 ? %w[has it] : %w[have them]
        warn "warning: #{entrypoints.join(' and ')} #{verb} no #{CLIENT_BOOTSTRAP_BLOCK_START} block, " \
             "so the #{hooks} this build adds will not run from #{pronoun}. " \
             "Update the Flutter client from the current ruflet-template."
      end

      def warn_foreign_client_bootstrap(hook_count)
        hooks = "#{hook_count} startup hook#{'s' unless hook_count == 1}"
        warn "warning: #{CLIENT_BOOTSTRAP_PATH} was not written by `ruflet build`, so it is left as it is " \
             "and the #{hooks} this build adds will not run. Rename that file to let the build generate it."
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
