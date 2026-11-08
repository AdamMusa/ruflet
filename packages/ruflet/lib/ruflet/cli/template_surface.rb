# frozen_string_literal: true

require "find"
require "json"
require "ripper"

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
      # Directories that hold no app source.
      SKIPPED_DIRS = %w[build vendor node_modules tmp log coverage public storage].freeze
      MAX_FILE_BYTES = 1_000_000
      MAX_FILES = 5_000

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
      # extensions: { extension key => bundled package } from the app's config.
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
        extensions.each do |key, package|
          next if surface[:packages].include?(package)
          next unless EXTENSION_PACKAGES.key?(package) || BASELINE_PACKAGES.include?(package)

          revision = EXTENSION_PACKAGES.fetch(package) { BASELINE_REVISION }
          found << Problem.new(kind: :extension, name: key, provides: package, revision: revision)
        end
        found
      rescue StandardError
        []
      end

      # DSL name => "path:line" of its first call, for each of names the app
      # calls as a method (`form(...)`, `form do`, `form key: 1`, a bare
      # `form`) and does not define itself. Comments, strings, symbols, local
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
      # the project, without build output, dependencies or dot directories.
      # Nothing outside a Ruflet project (no main.rb, ruflet.yaml or
      # services.yaml) is read.
      def ruby_files(project_root)
        rails_views = File.join(project_root, "app", "views", "ruflet")
        if File.file?(File.join(project_root, "config", "application.rb")) && Dir.exist?(rails_views)
          return Dir.glob(File.join(rails_views, "**", "*.rb")).sort.first(MAX_FILES)
        end
        return [] unless %w[main.rb ruflet.yaml ruflet.yml services.yaml].any? { |marker| File.file?(File.join(project_root, marker)) }

        files = []
        Find.find(project_root) do |path|
          if File.directory?(path)
            name = File.basename(path)
            Find.prune if path != project_root && (name.start_with?(".") || SKIPPED_DIRS.include?(name))
          elsif path.end_with?(".rb")
            files << path
            break if files.length >= MAX_FILES
          end
        end
        files.sort
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
          node.each { |child| stack << child if child.is_a?(Array) }
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

      # The lines a command prints for problems (strict: they are an error).
      def report(problems, template_root:, revision: nil, strict: false)
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
          lines << "  Until it has them, a control it lacks shows \"Unknown control\"."
        end
        lines <<
          if strict
            "  Failing because of --strict. Fetch the latest template with `ruflet doctor --fix`."
          else
            "  Fetch the latest template with `ruflet doctor --fix`, or pass --strict to fail instead."
          end
        lines
      end

      def short(revision)
        revision.to_s[0, 12]
      end

      def join_words(words)
        words.length <= 1 ? words.join : "#{words[0..-2].join(', ')} and #{words.last}"
      end
    end

    # The build, run and doctor side of TemplateSurface.
    module TemplateSurfaceCheck
      private

      # Reports what the app uses that the template at template_root lacks.
      # Returns false when strict makes that an error, true otherwise
      # (including when nothing could be checked).
      def check_template_surface(template_root, strict: false, config: nil, files: [])
        problems = TemplateSurface.problems(
          template_root, extensions: template_surface_extensions(config), files: files
        )
        return true if problems.empty?

        TemplateSurface.report(
          problems, template_root: template_root, revision: template_surface_revision(template_root), strict: strict
        ).each { |line| warn line }
        !strict
      rescue StandardError
        true
      end

      # { extension key => bundled package } for the extensions the config
      # selects (services included, as the build selects them).
      def template_surface_extensions(config)
        return {} unless config.is_a?(Hash) && respond_to?(:configured_extension_keys, true)

        send(:configured_extension_keys, config).each_with_object({}) do |key, selected|
          package = NewCommand::CLIENT_EXTENSION_MAP.dig(key, :package)
          selected[key] = package if package
        end
      rescue StandardError
        {}
      end

      # The template a build copies build/client from (a custom
      # RUFLET_CLIENT_DIR is its own template).
      def build_template_surface_root(client_dir)
        return client_dir if ENV["RUFLET_CLIENT_DIR"]

        installed_template_surface_root || client_dir
      end

      # The template already on this machine; nothing is fetched.
      def installed_template_surface_root
        return nil unless Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)

        Ruflet::CLI.send(:resolve_ruflet_client_template_root)
      rescue StandardError
        nil
      end

      def template_surface_revision(template_root)
        recorded = File.join(template_root, ".ruflet-template-revision")
        return File.read(recorded).strip if File.file?(recorded)
        return nil unless respond_to?(:installed_template_revision, true)

        send(:installed_template_revision, template_root)
      rescue StandardError
        nil
      end
    end
  end
end
