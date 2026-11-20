# frozen_string_literal: true

require "json"
require "stringio"
require_relative "tar"

module RufletCompat
  # A stand-in for the GitHub release the CLI downloads its prebuilt clients
  # from (`ruflet update`, `ruflet run --web/--desktop` without a cache, the
  # Rails generator's --desktop). Corpus entries opt in with
  # `network: "release"`; every other entry keeps the offline network, where
  # each request is answered 503.
  #
  # The release has the shape the CLI asks for (run_command.rb): a rolling
  # `prebuild-main` release carrying the completion manifest and one asset per
  # client, a `latest` release with the same assets, and 404 for the
  # per-version tags. Downloads redirect to a CDN host the way GitHub's do.
  # The archives have the layout build-ruflet-client.yml publishes: web and
  # Linux as `tar -C <dir> -czf ... .`, macOS as `ditto -c -k --keepParent
  # <app>`, Windows as the contents of the Release folder. The CLI extracts
  # them with the real host tools (lib/cli_child.rb), so what lands in the
  # client cache is what a developer's machine produces.
  #
  # Every archive is built once, when this file is loaded (before the CLI
  # runs, spawns anything or starts a thread), by plain Ruby: gzip with
  # stored deflate blocks, stored zip entries and a table CRC-32. No zlib
  # stream is involved, so the bytes are the same on every run, host and
  # zlib version, and no signal or thread switch during a request can
  # change or break them. (Zlib::GzipWriter, built lazily on the first
  # request, sometimes raised Zlib::BufError when the process was
  # interrupted mid-deflate; the CLI rescued it and a golden changed.)
  module ReleaseFixture
    API = "https://api.github.com/repos/AdamMusa/Ruflet/releases"
    DOWNLOAD = "https://github.com/AdamMusa/Ruflet/releases/download"
    CDN = "https://release-assets.githubusercontent.com/compat"
    ROLLING_TAG = "prebuild-main"
    LATEST_TAG = "compat-latest"
    PUBLISHED_AT = "2025-12-31T09:00:00Z"
    MANIFEST_ASSET = "ruflet_explorer-manifest.json"

    module_function

    # name => [archive kind, content]
    def asset_sources
      {
        "ruflet_explorer-web.tar.gz" => [:tar_gz, [
          ["./index.html", 0o644, "<!doctype html>\n<title>Ruflet Explorer (compat release)</title>\n"],
          ["./flutter_bootstrap.js", 0o644, "// compat release: flutter_bootstrap.js\n"],
          ["./main.dart.js", 0o644, "// compat release: main.dart.js\n"]
        ]],
        "ruflet_explorer-macos-universal.zip" => [:zip, [
          ["Ruflet Explorer.app/Contents/Info.plist", 0o644, "<?xml version=\"1.0\"?>\n<plist><dict/></plist>\n"],
          ["Ruflet Explorer.app/Contents/MacOS/Ruflet Explorer", 0o755, "#!/bin/sh\n# compat release: macOS client\n"]
        ]],
        "ruflet_explorer-linux-x64.tar.gz" => [:tar_gz, [
          ["./ruflet_explorer", 0o755, "#!/bin/sh\n# compat release: Linux client\n"],
          ["./lib/libapp.so", 0o644, "compat release: libapp.so\n"]
        ]],
        "ruflet_explorer-windows-x64.zip" => [:zip, [
          ["ruflet_explorer.exe", 0o644, "compat release: ruflet_explorer.exe\n"],
          ["flutter_windows.dll", 0o644, "compat release: flutter_windows.dll\n"]
        ]],
        MANIFEST_ASSET => [:raw, JSON.pretty_generate(
          "schema" => 1, "revision" => "c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00", "run_id" => "1",
          "ref" => "refs/heads/main", "explorer_ref" => "main", "completed_at" => PUBLISHED_AT
        )]
      }
    end

    def build_assets
      asset_sources.to_h do |name, (kind, content)|
        bytes = case kind
                when :tar_gz then tar_gz(content)
                when :zip then zip(content)
                else content.b
                end
        [name.freeze, bytes.freeze]
      end.freeze
    end

    def assets = ASSETS

    def release(tag, id:)
      {
        "id" => id,
        "tag_name" => tag,
        "name" => tag,
        "prerelease" => tag == ROLLING_TAG,
        "published_at" => PUBLISHED_AT,
        "assets" => assets.keys.each_with_index.map do |name, index|
          {
            "id" => (id * 100) + index + 1,
            "name" => name,
            "size" => assets[name].bytesize,
            "updated_at" => PUBLISHED_AT,
            "browser_download_url" => "#{DOWNLOAD}/#{tag}/#{name}"
          }
        end
      }
    end

    # [status, headers, body] for a GET of `url`.
    def respond(url)
      case url
      when "#{API}/tags/#{ROLLING_TAG}"
        [200, { "content-type" => "application/json" }, JSON.generate(release(ROLLING_TAG, id: 7))]
      when "#{API}/latest"
        [200, { "content-type" => "application/json" }, JSON.generate(release(LATEST_TAG, id: 6))]
      when %r{\A#{Regexp.escape(API)}/tags/}
        [404, { "content-type" => "application/json" }, JSON.generate("message" => "Not Found")]
      when %r{\A#{Regexp.escape(DOWNLOAD)}/[^/]+/([^/]+)\z}
        name = Regexp.last_match(1)
        assets.key?(name) ? [302, { "location" => "#{CDN}/#{name}" }, ""] : [404, {}, "Not Found"]
      when %r{\A#{Regexp.escape(CDN)}/([^/]+)\z}
        body = assets[Regexp.last_match(1)]
        body ? [200, { "content-type" => "application/octet-stream" }, body] : [404, {}, "Not Found"]
      else
        [404, {}, "Not Found"]
      end
    end

    # --- archives ------------------------------------------------------------

    def tar_gz(files)
      tar = StringIO.new(+"".b)
      Tar.write(tar, files.map { |path, mode, data| Tar::Entry.new(path: path, mode: mode, data: data) })
      gzip_stored(tar.string)
    end

    # RFC 1952 gzip around RFC 1951 stored (uncompressed) blocks: a fixed
    # header (mtime 1, no name, OS "unknown"), blocks of at most 65535
    # bytes, then CRC-32 and size. Any gzip reader accepts it.
    def gzip_stored(data)
      data = data.b
      out = [0x1f, 0x8b, 8, 0, 1, 0, 255].pack("CCCCVCC")
      chunks = data.empty? ? [+"".b] : data.scan(/.{1,65535}/mn)
      chunks.each_with_index do |chunk, index|
        out << [index == chunks.length - 1 ? 1 : 0, chunk.bytesize, chunk.bytesize ^ 0xffff].pack("Cvv") << chunk
      end
      out << [crc32(data), data.bytesize & 0xffff_ffff].pack("VV")
    end

    CRC_TABLE = Array.new(256) do |byte|
      8.times.reduce(byte) { |crc, _| crc.odd? ? (0xedb88320 ^ (crc >> 1)) : crc >> 1 }
    end.freeze

    def crc32(data)
      data.each_byte.reduce(0xffff_ffff) { |crc, byte| CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >> 8) } ^ 0xffff_ffff
    end

    # A stored (uncompressed) zip with Unix modes in the external attributes,
    # which is what ditto and unzip restore.
    def zip(files)
      out = +"".b
      central = +"".b
      files.each do |path, mode, data|
        name = path.b
        data = data.b
        crc = crc32(data)
        offset = out.bytesize
        out << [0x04034b50, 20, 0, 0, 0, 0x21, crc, data.bytesize, data.bytesize, name.bytesize, 0].pack("VvvvvvVVVvv")
        out << name << data
        central << [0x02014b50, (3 << 8) | 20, 20, 0, 0, 0, 0x21, crc, data.bytesize, data.bytesize,
                    name.bytesize, 0, 0, 0, 0, ((0o100000 | mode) << 16), offset].pack("VvvvvvvVVVvvvvvVV")
        central << name
      end
      out << central
      out << [0x06054b50, 0, 0, files.length, files.length, central.bytesize, out.bytesize - central.bytesize, 0].pack("VvvvvVVv")
      out
    end

    # Built here, at load, never on a request.
    ASSETS = build_assets
  end
end
