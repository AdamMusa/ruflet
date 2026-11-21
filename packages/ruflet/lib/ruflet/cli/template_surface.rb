# frozen_string_literal: true

require "find"
require "json"

require_relative "template_surface_revisions"

module Ruflet
  module CLI
    # CRIT-04: the Flutter template renders the controls and services listed in
    # its tool/conformance/ruflet_control_surface.json and bundles the extension
    # packages under ruflet_packages/. When the app uses one the template lacks,
    # build, run and doctor say which, and name the first template revision
    # that has it (template_surface_revisions.rb).
    #
    # The check is advisory. It never raises, it is skipped for a template
    # without a surface file (older templates), and it reads no app file unless
    # the template lacks something this ruflet knows.
    module TemplateSurface
      SURFACE_FILE = File.join("tool", "conformance", "ruflet_control_surface.json").freeze
      # Directories that hold no app source, or only tests and specs.
      SKIPPED_DIRS = %w[build vendor node_modules tmp log coverage public storage spec test].freeze
      # Methods that define the methods their symbol or string arguments name,
      # and which of those arguments: all, the first, or all but the first.
      DEFINERS = {
        "attr" => :all, "attr_reader" => :all, "attr_accessor" => :all,
        "define_method" => :first, "alias_method" => :first,
        "def_delegator" => :rest, "def_delegators" => :rest, "delegate" => :all,
        "let" => :first, "let!" => :first, "subject" => :first,
        "belongs_to" => :first, "has_one" => :first,
        "Struct.new" => :all, "Data.define" => :all
      }.freeze
      MAX_FILE_BYTES = 1_000_000
      MAX_FILES = 5_000
      # Directory entries visited at most, so a large asset tree cannot slow
      # a build or `ruflet run` down.
      MAX_ENTRIES = 50_000

      Problem = Struct.new(:kind, :name, :provides, :revision, :location, keyword_init: true)

      module_function

      # { wire_types: [...], packages: [...] }, or nil when the template has no
      # readable surface file.
      def load(template_root)
        return nil unless template_root

        path = File.join(template_root, SURFACE_FILE)
        return nil unless File.file?(path)

        entries = JSON.parse(File.read(path, encoding: Encoding::UTF_8))["entries"]
        return nil unless entries.is_a?(Array)

        packages_root = File.join(template_root, "ruflet_packages")
        packages = Dir.exist?(packages_root) ? Dir.children(packages_root).select { |name| File.directory?(File.join(packages_root, name)) } : []
        {
          wire_types: entries.filter_map { |entry| entry["wire_type"] if entry.is_a?(Hash) }.uniq,
          packages: packages
        }
      rescue StandardError
        nil
      end

      # DSL name => [wire type, family, first template revision], for each wire
      # type this ruflet knows that the template does not render.
      def unrendered_names(surface)
        names = {}
        WIRE_TYPES.each do |wire, (family, dsl_names, revision)|
          next if surface[:wire_types].include?(wire)

          dsl_names.each { |name| names[name] = [wire, family, revision] }
        end
        names
      end

      # What the app at project_root uses that the template lacks.
      # extensions: { extension key => bundled package } from the app's config,
      # or a callable returning it; it is called only when the template lacks a
      # bundled package this ruflet knows.
      def problems(template_root, project_root: Dir.pwd, extensions: {}, files: [])
        surface = load(template_root)
        return [] unless surface

        found = []
        missing = unrendered_names(surface)
        unless missing.empty?
          app_calls(project_root, missing.keys, files: files).each do |name, location|
            wire, family, revision = missing.fetch(name)
            found << Problem.new(kind: family == "service" ? :service : :control, name: name, provides: wire,
                                 revision: revision, location: location)
          end
        end
        lacking = EXTENSION_PACKAGES.keys - surface[:packages]
        unless lacking.empty?
          extensions = extensions.call if extensions.respond_to?(:call)
          (extensions || {}).each do |key, package|
            next unless lacking.include?(package)

            found << Problem.new(kind: :extension, name: key, provides: package, revision: EXTENSION_PACKAGES[package])
          end
        end
        found
      rescue StandardError
        []
      end

      # DSL name => "path:line" of its first call, for each of names the app
      # calls as a method (`form(...)`, `form do`, `form key: 1`, a bare
      # `form`) and does not define itself (`def`, `attr_reader`, `let`,
      # `define_method`, ... see DEFINERS). Comments, strings, symbols, local
      # variables and calls on a receiver do not count.
      def app_calls(project_root, names, files: [])
        return {} if names.empty?

        pattern = Regexp.new("\\b(?:#{names.sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }.join('|')})\\b")
        wanted = names.to_h { |name| [name, true] }
        calls = {}
        defined = {}
        (ruby_files(project_root) + files.map { |path| File.expand_path(path) }).uniq.each do |path|
          source = read_source(path)
          next unless source&.match?(pattern)

          require "ripper" # loaded only when a file may call a name the template lacks
          tree = Ripper.sexp(source)
          next unless tree

          relative = relative_path(path, project_root)
          each_call(tree) do |kind, name, line|
            if kind == :def
              defined[name] = true
            elsif wanted[name]
              location = "#{relative}:#{line}"
              calls[name] = location if calls[name].nil? || location_before?(location, calls[name])
            end
          end
        end
        calls.reject { |name, _| defined[name] }.sort.to_h
      end

      # The Ruby files of the app: app/views/ruflet in a Rails app, otherwise
      # the project, without build output, dependencies, installed gems,
      # tests, specs or dot directories.
      # Nothing outside a Ruflet project (no main.rb, ruflet.yaml, ruflet.yml
      # or services.yaml) is read.
      def ruby_files(project_root)
        rails_views = File.join(project_root, "app", "views", "ruflet")
        if File.file?(File.join(project_root, "config", "application.rb")) && Dir.exist?(rails_views)
          return Dir.glob(File.join(rails_views, "**", "*.rb")).sort.first(MAX_FILES)
        end
        return [] unless %w[main.rb ruflet.yaml ruflet.yml services.yaml].any? { |marker| File.file?(File.join(project_root, marker)) }

        files = []
        entries = 0
        Find.find(project_root) do |path|
          entries += 1
          break if entries > MAX_ENTRIES

          if File.directory?(path)
            name = File.basename(path)
            Find.prune if path != project_root && (name.start_with?(".") || SKIPPED_DIRS.include?(name) || gem_dir?(path))
          elsif path.end_with?(".rb")
            files << path
            break if files.length >= MAX_FILES
          end
        end
        files.sort
      end

      # A RubyGems install directory (one with specifications/ and gems/),
      # such as gems/ruby/3.4.0 after `bundle config set path gems`: its gems
      # are not the app.
      def gem_dir?(path)
        File.directory?(File.join(path, "specifications")) && File.directory?(File.join(path, "gems"))
      end

      def read_source(path)
        return nil unless File.file?(path) && File.size(path) <= MAX_FILE_BYTES

        source = File.read(path, encoding: Encoding::UTF_8)
        source.valid_encoding? ? source : nil
      rescue StandardError
        nil
      end

      # Yields [:call, name, line] for every receiverless method call and
      # [:def, name, line] for every method definition in a Ripper tree.
      def each_call(tree)
        stack = [tree]
        until stack.empty?
          node = stack.pop
          next unless node.is_a?(Array)

          ident =
            case node[0]
            when :fcall, :vcall, :command then [:call, node[1]]
            when :def then [:def, node[1]]
            when :defs then [:def, node[3]]
            end
          if ident && ident[1].is_a?(Array) && ident[1][0] == :@ident
            yield ident[0], ident[1][1], ident[1][2][0]
          end
          defined_names(node).each { |name, line| yield :def, name, line }
          node.each { |child| stack << child if child.is_a?(Array) }
        end
      end

      # [name, line] for each method that node defines without `def`: an
      # `alias`, or a DEFINERS call with literal arguments.
      def defined_names(node)
        return [literal_name(node[1])].compact if node[0] == :alias

        definer, args =
          case node[0]
          when :command then [token(node[1]), node[2]]
          when :command_call then [const_definer(node[1], node[3]), node[4]]
          when :method_add_arg
            callee = node[1]
            if callee.is_a?(Array) && callee[0] == :fcall
              [token(callee[1]), node[2]]
            elsif callee.is_a?(Array) && callee[0] == :call
              [const_definer(callee[1], callee[3]), node[2]]
            end
          end
        which = DEFINERS[definer&.first]
        return [] unless which

        names = argument_nodes(args).map { |arg| literal_name(arg) }
        names = names.first(1) if which == :first
        names = names.drop(1) if which == :rest
        names.compact
      end

      # ["Struct.new", line] for `Struct.new`/`::Struct.new` (and Data.define).
      def const_definer(receiver, method)
        return nil unless receiver.is_a?(Array) && %i[var_ref top_const_ref].include?(receiver[0])

        const = token(receiver[1])
        name = token(method)
        const && name && ["#{const.first}.#{name.first}", name.last]
      end

      # [text, line] of an identifier or constant token.
      def token(node)
        return nil unless node.is_a?(Array) && %i[@ident @const].include?(node[0]) && node[1].is_a?(String)

        [node[1], node[2].is_a?(Array) ? node[2][0] : nil]
      end

      # The argument nodes of a call, splatted array literals included.
      def argument_nodes(args)
        args = args[1] if args.is_a?(Array) && args[0] == :arg_paren
        args = args[1] if args.is_a?(Array) && args[0] == :args_add_block
        return [] unless args.is_a?(Array)
        return args unless args[0] == :args_add_star

        star = args[2]
        argument_nodes(args[1]) + (star.is_a?(Array) && star[0] == :array ? Array(star[1]) : []) + args.drop(3)
      end

      # [name, line] of a symbol, plain string or %i/%w word, otherwise nil.
      def literal_name(node)
        return nil unless node.is_a?(Array)

        case node[0]
        when :symbol_literal
          inner = node[1]
          token(inner.is_a?(Array) && inner[0] == :symbol ? inner[1] : inner)
        when :string_literal, :dyna_symbol
          content = node[1]
          parts = content.is_a?(Array) && content[0] == :string_content ? content.drop(1) : content
          part = parts.first if parts.is_a?(Array) && parts.length == 1
          [part[1], part[2][0]] if part.is_a?(Array) && part[0] == :@tstring_content
        when :@tstring_content
          [node[1], node[2][0]]
        end
      end

      def location_before?(left, right)
        left_path, left_line = left.split(/:(?=\d+\z)/)
        right_path, right_line = right.split(/:(?=\d+\z)/)
        ([left_path, left_line.to_i] <=> [right_path, right_line.to_i]).negative?
      end

      def relative_path(path, root)
        expanded = File.expand_path(path)
        prefix = "#{File.expand_path(root)}/"
        expanded.start_with?(prefix) ? expanded.delete_prefix(prefix) : expanded
      end

      FETCH_ADVICE = "Fetch the latest template with `ruflet doctor --fix`"

      # The lines a command prints for problems (strict: they are an error).
      # advice says how to get a newer template (see
      # TemplateSurfaceCheck.advice).
      def report(problems, template_root:, revision: nil, strict: false, advice: FETCH_ADVICE)
        counts = %i[control service extension].filter_map do |kind|
          count = problems.count { |problem| problem.kind == kind }
          "#{count} #{kind}#{'s' unless count == 1}" if count.positive?
        end
        lines = ["#{strict ? 'error' : 'warning'}: the Flutter template lacks #{join_words(counts)} this app uses:"]
        problems.each do |problem|
          subject =
            if problem.kind == :extension
              "extension #{problem.name} (#{problem.provides})"
            else
              "#{problem.name} (#{problem.provides}), #{problem.location}"
            end
          needs = problem.revision ? "needs ruflet-template #{short(problem.revision)} or newer" : "no ruflet-template revision has it yet"
          lines << "  #{subject}: #{needs}"
        end
        lines << "  Template: #{template_root}#{" (revision #{short(revision)})" if revision}"
        if !strict && problems.any? { |problem| problem.kind == :control }
          lines << "  An app built from this template shows \"Unknown control\" in place of a control it lacks."
        end
        lines << (strict ? "  Failing because of --strict. #{advice}." : "  #{advice}, or pass --strict to fail instead.")
        lines
      end

      def short(revision)
        revision.to_s[0, 12]
      end

      def join_words(words)
        words.length <= 1 ? words.join : "#{words[0..-2].join(', ')} and #{words.last}"
      end
    end

    # The build, run and doctor side of TemplateSurface. Its functions take the
    # command object (cli, Ruflet::CLI itself in the ruflet executable) instead
    # of being mixed into RunCommand, BuildCommand or ExtraCommand: including a
    # module there reorders Ruflet::CLI's ancestors, and with them the
    # FlutterSdk and RunCommand versions of download_file and extract_archive.
    module TemplateSurfaceCheck
      module_function

      # Reports what the app uses that the template at template_root lacks.
      # Returns false when strict makes that an error, true otherwise
      # (including when nothing could be checked). config is the app's config,
      # or a callable returning it, called only when the template lacks a
      # bundled package.
      def check(cli, template_root, strict: false, config: nil, files: [])
        selected = -> { extensions(cli, config.respond_to?(:call) ? config.call : config) }
        problems = TemplateSurface.problems(template_root, extensions: selected, files: files)
        return true if problems.empty?

        TemplateSurface.report(
          problems,
          template_root: template_root, revision: revision(cli, template_root), strict: strict,
          advice: advice(cli, template_root)
        ).each { |line| warn line }
        !strict
      rescue StandardError
        true
      end

      # { extension key => bundled package } for the extensions the config
      # selects (services included, as the build selects them).
      def extensions(cli, config)
        return {} unless config.is_a?(Hash) && cli.respond_to?(:configured_extension_keys, true)

        cli.send(:configured_extension_keys, config).each_with_object({}) do |key, selected|
          package = NewCommand::CLIENT_EXTENSION_MAP.dig(key, :package)
          selected[key] = package if package
        end
      rescue StandardError
        {}
      end

      # The template a build copies build/client from (a custom
      # RUFLET_CLIENT_DIR is its own template).
      def build_root(cli, client_dir)
        return client_dir if ENV["RUFLET_CLIENT_DIR"]

        installed_root(cli) || client_dir
      end

      # The template run checks: a RUFLET_CLIENT_DIR that names a directory
      # is the client run --web and --desktop open and the one `ruflet build`
      # uses, so it is checked as its own template, as build checks it;
      # otherwise the installed template is.
      def run_root(cli)
        client_dir = ENV["RUFLET_CLIENT_DIR"].to_s
        return client_dir if !client_dir.strip.empty? && Dir.exist?(client_dir)

        installed_root(cli)
      rescue StandardError
        nil
      end

      # The template already on this machine; nothing is fetched.
      def installed_root(cli)
        return nil unless cli.respond_to?(:resolve_ruflet_client_template_root, true)

        cli.send(:resolve_ruflet_client_template_root)
      rescue StandardError
        nil
      end

      # How to get a newer template than template_root. `ruflet doctor --fix`
      # refreshes only the cached one, and RUFLET_CLIENT_DIR, RUFLET_TEMPLATE_ROOT
      # and a ruflet-template checkout beside this ruflet take precedence over
      # it, so a template from one of those is named instead.
      def advice(cli, template_root)
        root = File.expand_path(template_root)
        unchanged = "(`ruflet doctor --fix` does not change it)"
        client_dir = ENV["RUFLET_CLIENT_DIR"].to_s.strip
        if !client_dir.empty? && File.expand_path(client_dir) == root
          return "Update the client in RUFLET_CLIENT_DIR from the latest ruflet-template #{unchanged}"
        end

        explicit = ENV["RUFLET_TEMPLATE_ROOT"].to_s.strip
        if !explicit.empty? && [explicit, File.join(explicit, "templates", "ruflet_flutter_template")].any? { |path| File.expand_path(path) == root }
          return "Update the template in RUFLET_TEMPLATE_ROOT to the latest ruflet-template #{unchanged}"
        end

        cached = cli.send(:cached_ruflet_client_template_root) if cli.respond_to?(:cached_ruflet_client_template_root, true)
        if cached && File.expand_path(cached) != root && root.end_with?("/templates/ruflet_flutter_template")
          return "Update the ruflet-template checkout #{File.expand_path('../..', root)} #{unchanged}"
        end

        TemplateSurface::FETCH_ADVICE
      rescue StandardError
        TemplateSurface::FETCH_ADVICE
      end

      # The revision a client recorded when it was copied, otherwise that of
      # the installed template: the cached one's, or the git HEAD of a
      # ruflet-template checkout (<checkout>/templates/ruflet_flutter_template).
      # Any other directory, such as a client in RUFLET_CLIENT_DIR, has none:
      # the git HEAD above it would be the app's, not the template's.
      def revision(cli, template_root)
        recorded = File.join(template_root, ".ruflet-template-revision")
        return File.read(recorded).strip if File.file?(recorded)
        return nil unless File.expand_path(template_root).end_with?("/templates/ruflet_flutter_template")
        return nil unless cli.respond_to?(:installed_template_revision, true)

        cli.send(:installed_template_revision, template_root)
      rescue StandardError
        nil
      end
    end
  end
end
