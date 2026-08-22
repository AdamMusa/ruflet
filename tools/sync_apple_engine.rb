# frozen_string_literal: true

require "digest"
require "fileutils"
require "optparse"
require "pathname"

module RufletAppleEngineSync
  DEFAULT_SOURCE = "/tmp/ruflet-recovery.QUn8c1/templates/ruflet_flutter_template/apple_packages/ruflet_apple"
  DEFAULT_TARGET = "/Users/macbookpro/Documents/Izeesoft/FlutterApp/ruflet-template/templates/ruflet_flutter_template/apple_packages/ruflet_apple"
  REQUIRED_MARKERS = ["Package.swift", "Sources/RufletEngine/RufletApp.swift"].freeze
  IGNORED_COMPONENTS = %w[.git .build .swiftpm .DS_Store].freeze

  module_function

  def run(argv, source: ENV.fetch("RUFLET_APPLE_ENGINE_SOURCE", DEFAULT_SOURCE),
          target: ENV.fetch("RUFLET_APPLE_ENGINE_TARGET", DEFAULT_TARGET))
    options = { check: false, only: [] }
    OptionParser.new do |parser|
      parser.on("--check") { options[:check] = true }
      parser.on("--only PATH") { |path| options[:only] << normalize_relative(path) }
    end.parse!(argv)

    source_root = validated_root(source, role: "source")
    target_root = validated_root(target, role: "target")
    selected = options[:only]

    if options[:check]
      drift = drift_entries(source_root, target_root, selected)
      if drift.empty?
        puts "Apple renderer copy matches the authoritative source#{selection_suffix(selected)}."
        return 0
      end

      warn "Apple renderer copy has drift#{selection_suffix(selected)}:"
      drift.each { |entry| warn "  #{entry}" }
      return 1
    end

    sync(source_root, target_root, selected)
    puts "Synced authoritative Apple renderer#{selection_suffix(selected)}."
    0
  rescue OptionParser::ParseError, ArgumentError => error
    warn error.message
    2
  end

  def validated_root(path, role:)
    root = Pathname.new(path).expand_path
    raise ArgumentError, "Apple renderer #{role} is missing: #{root}" unless root.directory?

    missing = REQUIRED_MARKERS.reject { |marker| root.join(marker).file? }
    unless missing.empty?
      raise ArgumentError,
            "Refusing Apple renderer #{role} without markers: #{missing.join(', ')}"
    end
    root
  end

  def normalize_relative(path)
    relative = Pathname.new(path.to_s).cleanpath
    if relative.absolute? || relative.to_s == "." || relative.each_filename.any? { |part| part == ".." }
      raise ArgumentError, "--only must stay inside the Apple renderer: #{path}"
    end
    relative.to_s
  end

  def sync(source, target, selected)
    source_files = files(source, selected)
    source_files.each do |relative|
      destination = target.join(relative)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(source.join(relative), destination, preserve: true)
    end

    return unless selected.empty?

    stale = files(target, []) - source_files
    stale.each { |relative| FileUtils.rm_f(target.join(relative)) }
    remove_empty_directories(target)
  end

  def drift_entries(source, target, selected)
    source_files = files(source, selected)
    target_files = files(target, selected)
    entries = []
    (source_files - target_files).each { |path| entries << "missing: #{path}" }
    (target_files - source_files).each { |path| entries << "stale: #{path}" }
    (source_files & target_files).each do |path|
      next if Digest::SHA256.file(source.join(path)) == Digest::SHA256.file(target.join(path))

      entries << "changed: #{path}"
    end
    entries.sort
  end

  def files(root, selected)
    candidates = if selected.empty?
      root.glob("**/*", File::FNM_DOTMATCH)
    else
      selected.flat_map do |relative|
        path = root.join(relative)
        raise ArgumentError, "Selected Apple renderer path is missing: #{relative}" unless path.exist?

        path.directory? ? path.glob("**/*", File::FNM_DOTMATCH) : [path]
      end
    end

    candidates.filter_map do |path|
      next unless path.file?

      relative = path.relative_path_from(root)
      next if relative.each_filename.any? { |part| IGNORED_COMPONENTS.include?(part) }

      relative.to_s
    end.uniq.sort
  end

  def remove_empty_directories(root)
    root.glob("**/*", File::FNM_DOTMATCH)
      .select(&:directory?)
      .reject { |path| path == root }
      .sort_by { |path| -path.each_filename.count }
      .each do |path|
        next if path.each_filename.any? { |part| IGNORED_COMPONENTS.include?(part) }

        Dir.rmdir(path) if path.children.empty?
      rescue SystemCallError
        nil
      end
  end

  def selection_suffix(selected)
    selected.empty? ? "" : " for #{selected.join(', ')}"
  end
end

exit RufletAppleEngineSync.run(ARGV) if $PROGRAM_NAME == __FILE__
