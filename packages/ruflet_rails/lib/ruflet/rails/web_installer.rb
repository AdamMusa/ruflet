# frozen_string_literal: true

require "json"
require "fileutils"
require "tmpdir"
require "open3"

module Ruflet
  module Rails
    # Installs the prebuilt Ruflet web client into a Rails app's frontend/
    # directory. The web client is the `ruflet_client-web.tar.gz` release asset
    # (the same prebuilt Flutter web build shipped on GitHub releases) — so the
    # Rails app serves a web frontend without ever running a Flutter build.
    #
    #   rake ruflet:web
    #
    # The extracted build is what Ruflet::Rails.web_app serves (its default
    # build dir is <Rails.root>/frontend).
    module WebInstaller
      module_function

      REPO       = "AdamMusa/Ruflet"
      ASSET_NAME = "ruflet_client-web.tar.gz"
      TARGET_DIR = "frontend"

      # Downloads and extracts the web client into <root>/<dir>. Returns true on
      # success. The asset name and release tag are overridable via ENV so a
      # project can pin a specific build.
      def install!(root:, dir: TARGET_DIR, asset_name: env_asset_name, tag: env_tag, force: true)
        target = File.join(root.to_s, dir)

        url = release_asset_url(asset_name, tag: tag)
        unless url
          warn "Ruflet web client asset #{asset_name.inspect} not found in the #{REPO} release#{tag ? " #{tag}" : " (latest)"}."
          return false
        end

        Dir.mktmpdir("ruflet-web-") do |tmp|
          archive = File.join(tmp, asset_name)
          return false unless download(url, archive)

          staging = File.join(tmp, "frontend")
          FileUtils.mkdir_p(staging)
          unless safe_archive?(archive) && extract(archive, staging)
            warn "Failed to safely extract #{asset_name}."
            return false
          end

          unless File.file?(File.join(staging, "index.html"))
            warn "Extracted web client but no index.html was found."
            return false
          end

          return false if Dir.exist?(target) && !force

          replace_target(staging, target)
        end

        puts "Installed Ruflet web client into #{target} (#{asset_name})."
        true
      rescue SystemCallError => e
        warn "Failed to install Ruflet web client into #{target}: #{e.message}"
        false
      end

      def release_asset_url(asset_name, tag: nil)
        api = tag ? "releases/tags/#{tag}" : "releases/latest"
        release = github_json("https://api.github.com/repos/#{REPO}/#{api}")
        return nil unless release

        asset = Array(release["assets"]).find { |a| a["name"] == asset_name }
        unless asset
          names = Array(release["assets"]).map { |a| a["name"] }
          warn "Available release assets: #{names.join(', ')}" unless names.empty?
        end
        asset && asset["browser_download_url"]
      end

      def github_json(url)
        out, status = Open3.capture2(
          "curl", "-sSL", "--fail",
          "-H", "Accept: application/vnd.github+json",
          "-H", "User-Agent: ruflet_rails",
          url
        )
        return nil unless status.success?

        JSON.parse(out)
      rescue JSON::ParserError
        nil
      end

      def download(url, path)
        ok = system("curl", "-sSL", "--fail", "-o", path, url)
        warn "Download failed: #{url}" unless ok
        ok
      end

      def extract(archive, target)
        system("tar", "-xzf", archive, "-C", target)
      end

      def safe_archive?(archive)
        out, status = Open3.capture2("tar", "-tzf", archive)
        return false unless status.success?

        out.lines.all? do |line|
          path = line.strip
          !path.start_with?("/") && path.split("/").none?("..")
        end
      end

      def replace_target(staging, target)
        FileUtils.mkdir_p(File.dirname(target))
        backup = "#{target}.ruflet-backup"
        FileUtils.rm_rf(backup)
        FileUtils.mv(target, backup) if File.exist?(target)
        FileUtils.mv(staging, target)
        FileUtils.rm_rf(backup)
      rescue StandardError
        FileUtils.rm_rf(target)
        FileUtils.mv(backup, target) if File.exist?(backup)
        raise
      end

      def env_asset_name
        value = ENV["RUFLET_RAILS_WEB_ARTIFACT"].to_s.strip
        value.empty? ? ASSET_NAME : value
      end

      def env_tag
        value = ENV["RUFLET_RAILS_WEB_TAG"].to_s.strip
        value.empty? ? nil : value
      end
    end
  end
end
