# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "stringio"
require "yaml"
require_relative "tar"

module RufletCompat
  # Freezes a ruflet-template revision into fixtures/template so the goldens
  # never depend on a template checkout, the network, or template drift.
  #
  #   ruby test/compat/compat.rb vendor-template --repo ../ruflet-template [--ref origin/main]
  #
  # The archive is the template's tracked files at that commit with three
  # documented, deterministic reductions (see TRANSFORMATIONS). It only has to
  # exercise the CLI: Flutter, pod and the generators are stubbed, so no file in
  # it is ever compiled.
  module VendorTemplate
    SUBDIR = "templates/ruflet_flutter_template"
    INTEGRITY = "tool/conformance/ruflet_source_integrity.json"
    TRANSFORMATIONS = [
      "ruflet_packages/: only each package's pubspec.yaml and lib/<package>.dart are kept " \
      "(the CLI copies, prunes and verifies these trees but never reads Dart sources)",
      "#{INTEGRITY}: \"files\" is restricted to the kept ruflet_packages files; every kept " \
      "entry and every other key is unchanged, so the CLI's integrity check still passes",
      "binary files (NUL byte or invalid UTF-8) are replaced by a one-line text placeholder " \
      "naming the original sha256 and size (the CLI only copies them; the icon/splash " \
      "generators that would read them are stubbed)"
    ].freeze

    module_function

    def run(repo:, ref:, out_dir:)
      sha = git(repo, "rev-parse", "--verify", "#{ref}^{commit}").strip
      archive = git(repo, "archive", "--format=tar", sha, SUBDIR)
      entries = Tar.read(StringIO.new(archive)).filter_map do |entry|
        next unless entry.path.start_with?("#{SUBDIR}/")

        relative = entry.path.delete_prefix("#{SUBDIR}/")
        next if relative.empty? || relative.end_with?("/")

        Tar::Entry.new(path: relative, mode: (entry.mode & 0o111).zero? ? 0o644 : 0o755, data: entry.data)
      end

      kept_packages = kept_package_files(entries)
      files = {}
      vendored = entries.filter_map do |entry|
        if entry.path.start_with?("ruflet_packages/")
          next unless kept_packages.include?(entry.path)
        end

        data = entry.data
        record = { "mode" => format("%o", entry.mode) }
        if entry.path == INTEGRITY
          data = restrict_integrity(data, kept_packages)
          record["restricted_from_sha256"] = Digest::SHA256.hexdigest(entry.data)
        elsif binary?(data)
          record["placeholder_for"] = { "sha256" => Digest::SHA256.hexdigest(data), "size" => data.bytesize }
          data = "ruflet compat placeholder for #{entry.path} " \
                 "(sha256 #{record['placeholder_for']['sha256']}, #{data.bytesize} bytes)\n"
        end
        record["sha256"] = Digest::SHA256.hexdigest(data)
        files[entry.path] = record
        Tar::Entry.new(path: "ruflet_flutter_template/#{entry.path}", mode: entry.mode, data: data)
      end.sort_by(&:path)

      FileUtils.mkdir_p(out_dir)
      File.open(File.join(out_dir, "ruflet_flutter_template.tar"), "wb") { |io| Tar.write(io, vendored) }
      source = {
        "repository" => "AdamMusa/ruflet-template",
        "commit" => sha,
        "subdirectory" => SUBDIR,
        "regenerate" => "ruby packages/ruflet/test/compat/compat.rb vendor-template --repo <ruflet-template clone> --ref #{sha}",
        "transformations" => TRANSFORMATIONS,
        "files" => files.sort.to_h
      }
      File.write(File.join(out_dir, "SOURCE.json"), "#{JSON.pretty_generate(source)}\n")
      { commit: sha, files: files.length }
    end

    def kept_package_files(entries)
      by_path = entries.to_h { |entry| [entry.path, entry] }
      kept = []
      entries.each do |entry|
        next unless entry.path.start_with?("ruflet_packages/") && File.basename(entry.path) == "pubspec.yaml"

        kept << entry.path
        name = (YAML.safe_load(entry.data.dup.force_encoding(Encoding::UTF_8)) || {})["name"].to_s
        library = File.join(File.dirname(entry.path), "lib", "#{name}.dart")
        kept << library if !name.empty? && by_path.key?(library)
      end
      kept.sort
    end

    def restrict_integrity(data, kept_packages)
      manifest = JSON.parse(data.dup.force_encoding(Encoding::UTF_8))
      kept = kept_packages.map { |path| path.delete_prefix("ruflet_packages/") }
      manifest["files"] = manifest.fetch("files").select { |path, _| kept.include?(path) }
      "#{JSON.pretty_generate(manifest)}\n"
    end

    def binary?(data)
      return true if data.include?("\0".b)

      !data.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end

    def git(repo, *args)
      out, err, status = Open3.capture3("git", "-C", repo, *args, binmode: true)
      raise "git #{args.join(' ')} failed: #{err}" unless status.success?

      out
    end
  end
end
