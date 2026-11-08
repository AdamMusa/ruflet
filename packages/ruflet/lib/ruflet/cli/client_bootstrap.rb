# frozen_string_literal: true

require "fileutils"

module Ruflet
  module CLI
    # Writes lib/ruflet_bootstrap.g.dart into the Flutter client: the ordered
    # hook lists the template entrypoints (lib/main.self.dart and
    # lib/main.server.dart) run just before runApp and after the first frame.
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
    #
    # With no hooks the file is the default ruflet-template ships, byte for
    # byte, so a build that uses no such feature produces the same client.
    module ClientBootstrap
      CLIENT_BOOTSTRAP_PATH = File.join("lib", "ruflet_bootstrap.g.dart").freeze
      # Phase => the list the entrypoints read for it.
      CLIENT_BOOTSTRAP_PHASES = {
        pre_run_app: "rufletPreRunAppHooks",
        post_first_frame: "rufletPostFirstFrameHooks"
      }.freeze
      CLIENT_BOOTSTRAP_HOOK_PROVIDERS = [].freeze

      CLIENT_BOOTSTRAP_IMPORT_PATTERN = %r{\A(?:(?:package:)?[A-Za-z0-9_][A-Za-z0-9_./-]*\.dart|dart:[a-z_]+)\z}
      CLIENT_BOOTSTRAP_FUNCTION_PATTERN = /\A[A-Za-z_$][A-Za-z0-9_$]*(?:\.[A-Za-z_$][A-Za-z0-9_$]*)?\z/

      CLIENT_BOOTSTRAP_HEADER = <<~DART
        // GENERATED FILE. DO NOT EDIT.
        //
        // `ruflet build` writes this file into the Flutter client on every build.
        // lib/main.self.dart and lib/main.server.dart run its hooks in list order:
        //
        // * rufletPreRunAppHooks are awaited one at a time just before runApp, once
        //   the Flutter binding and every extension are initialized.
        // * rufletPostFirstFrameHooks run one at a time after the first frame.
        //
        // A hook that throws is reported through FlutterError.reportError and does
        // not stop the hooks after it or the app. With both lists empty the
        // entrypoints skip the hooks entirely. Build features add hooks through
        // Ruflet::CLI::ClientBootstrap in the ruflet gem.
      DART

      CLIENT_BOOTSTRAP_TYPEDEF = <<~DART
        /// A bootstrap hook: a top-level or static function that takes no
        /// arguments.
        typedef RufletBootstrapHook = FutureOr<void> Function();
      DART

      private

      # Writes the bootstrap for this build and returns its path. An unchanged
      # file is left alone so it does not look modified to Flutter's build.
      def write_client_bootstrap(client_dir, config = {}, platform: nil, self_contained: false)
        hooks = client_bootstrap_hooks(config, platform: platform, self_contained: self_contained)
        content = render_client_bootstrap(hooks)
        path = File.join(client_dir, CLIENT_BOOTSTRAP_PATH)
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
        out << "\n" << CLIENT_BOOTSTRAP_TYPEDEF
        CLIENT_BOOTSTRAP_PHASES.each do |phase, list_name|
          out << "\n"
          if entries[phase].empty?
            out << "const #{list_name} = <RufletBootstrapHook>[];\n"
          else
            out << "const #{list_name} = <RufletBootstrapHook>[\n"
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
