# frozen_string_literal: true

require "digest"
require "fileutils"

module Ruflet
  module CLI
    # Installs a downloaded archive (a prebuilt client or the managed Flutter
    # SDK) so that its destination only ever holds a complete, checked copy:
    # the archive is checked against the SHA-256 its publisher lists, unpacked
    # beside the destination, and only then swapped into place. A truncated
    # download, a failed or interrupted extraction, or a digest mismatch
    # leaves the previous install untouched.
    #
    # Its functions take the command object (cli) and call its
    # extract_archive, instead of being mixed in: including a module into
    # RunCommand or FlutterSdk would reorder Ruflet::CLI's ancestors, and with
    # them which download_file and extract_archive the CLI runs.
    module VerifiedInstall
      module_function

      # Written beside the managed SDK's flutter/ directory (never inside the
      # SDK's git checkout) once it is installed completely.
      COMPLETE_MARKER = ".ruflet-complete"

      # The SHA-256 a publisher lists, as GitHub's asset "digest"
      # ("sha256:<hex>") or Flutter's releases_<host>.json "sha256" (bare hex).
      # nil when absent or in another algorithm.
      def sha256_from(value)
        hex = value.to_s.strip.downcase.delete_prefix("sha256:")
        hex.match?(/\A\h{64}\z/) ? hex : nil
      end

      # true when the archive matches its published SHA-256, or when none is
      # published (with a warning). false, with a warning, on a mismatch.
      def verified?(archive_path, published, label:)
        expected = sha256_from(published)
        unless expected
          warn "No SHA-256 is published for #{label}; installing it unverified"
          return true
        end

        actual = Digest::SHA256.file(archive_path).hexdigest
        return true if actual == expected

        warn "#{label} does not match its published SHA-256 (expected #{expected}, got #{actual}); not installing it"
        false
      end

      # Unpacks archive_path with cli's extract_archive into a directory
      # beside dest and returns that directory, or nil when the extractor
      # fails. The caller promotes it or removes it (see discard).
      def stage(cli, archive_path, dest)
        sweep_abandoned(dest)
        staging = "#{dest}.partial-#{Process.pid}"
        FileUtils.rm_rf(staging)
        FileUtils.mkdir_p(staging)
        return staging if cli.send(:extract_archive, archive_path, staging)

        discard(staging)
        nil
      rescue Exception # also on Ctrl-C (Interrupt)
        discard(staging)
        raise
      end

      # Moves a staged copy to dest. Whatever dest held moves aside first and
      # is removed only once the staged copy is in place; if the move fails,
      # it is put back.
      def promote(staging, dest)
        retired = nil
        if File.exist?(dest) || File.symlink?(dest)
          retired = "#{dest}.old-#{Process.pid}"
          FileUtils.rm_rf(retired)
          rename(dest, retired)
        end
        begin
          rename(staging, dest)
        rescue StandardError
          rename(retired, dest) if retired && !File.exist?(dest)
          raise
        end
        FileUtils.rm_rf(retired) if retired
        dest
      end

      # Windows refuses to rename a directory while something holds a file in
      # it open, which an antivirus scan of freshly unpacked files briefly
      # does. Retry those refusals there for a while before giving up.
      RENAME_RETRIES = 30
      RENAME_RETRY_SECONDS = 0.5

      def rename(from, to)
        attempts = 0
        begin
          File.rename(from, to)
        rescue Errno::EACCES, Errno::EPERM, Errno::EBUSY
          attempts += 1
          raise if !Gem.win_platform? || attempts >= RENAME_RETRIES

          sleep RENAME_RETRY_SECONDS
          retry
        end
      end

      def discard(path)
        FileUtils.rm_rf(path) if path && (File.exist?(path) || File.symlink?(path))
      end

      # Staging and retired copies a killed process left behind
      # (<dest>.partial-<pid>, <dest>.old-<pid>). A copy whose process still
      # runs belongs to a concurrent install and is left alone.
      def sweep_abandoned(dest)
        parent = File.dirname(dest)
        return unless File.directory?(parent)

        pattern = /\A#{Regexp.escape(File.basename(dest))}\.(?:partial|old)-(\d+)\z/
        Dir.children(parent).each do |entry|
          pid = entry[pattern, 1]&.to_i
          next unless pid
          next if pid != Process.pid && process_alive?(pid)

          FileUtils.rm_rf(File.join(parent, entry))
        end
      rescue SystemCallError
        nil
      end

      def process_alive?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      rescue StandardError
        true
      end

      def human_size(bytes)
        units = %w[KB MB GB TB]
        size = bytes.to_f
        unit = -1
        while size >= 1024 && unit < units.length - 1
          size /= 1024
          unit += 1
        end
        unit.negative? ? "#{bytes} bytes" : format("%.1f %s", size, units[unit])
      end
    end
  end
end
