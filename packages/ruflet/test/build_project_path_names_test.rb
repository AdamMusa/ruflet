# frozen_string_literal: true

require_relative "test_helper"
require "digest"
require "fileutils"
require "json"
require "pathname"
require "rbconfig"
require "uri"
require "yaml"

# Project folders whose name or path holds characters other than letters,
# digits and -._ (issue #139): a space, an "é", an apostrophe, "&", brackets.
class RufletCliBuildProjectPathNamesTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  class DummyRunner
    include Ruflet::CLI::RunCommand
  end

  # The directory flutter_tools writes a project's files to under
  # flutter_assets/assets/: Dart's Uri(pathSegments: ["assets", name, ...])
  # (Dart 3.11, Flutter 3.41.2). `flutter build bundle` wrote the first seven
  # to disk under exactly these names.
  FLUTTER_ASSET_NAMES = {
    "shop" => "shop",
    "My Shop" => "My%20Shop",
    "café" => "caf%C3%A9",
    "Bob's" => "Bob's",
    "x[1]" => "x%5B1%5D",
    "a{b}" => "a%7Bb%7D",
    "Tom & Jerry" => "Tom%20&%20Jerry",
    "C# App" => "C%23%20App",
    "100%" => "100%25",
    "50%25" => "50%2525",
    "a*b" => "a*b",
    "q?" => "q%3F",
    "semi;colon=1,2" => "semi;colon=1,2",
    "at@x:y" => "at@x:y",
    "tilde~!$()+" => "tilde~!$()+",
    "日本" => "%E6%97%A5%E6%9C%AC",
    "a^b`c|d" => "a%5Eb%60c%7Cd",
    "back\\slash" => "back%5Cslash",
    "quo\"te" => "quo%22te",
    "lt<gt>" => "lt%3Cgt%3E",
    "emoji😀" => "emoji%F0%9F%98%80",
    "dash-under_score.dot" => "dash-under_score.dot"
  }.freeze

  # Names Flutter stores as they are, which therefore worked before #139.
  # Their native configuration must stay byte for byte what it was.
  UNCHANGED_NAMES = ["shop", "my_app", "dash-under_score.dot", "a*b", "semi;colon=1,2", "at@x:y", "tilde~!$()+"].freeze

  PLIST = <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \t<key>CFBundleName</key>
    \t<string>ruflet_client</string>
    </dict>
    </plist>
  PLIST

  MANIFEST = <<~XML
    <manifest xmlns:android="http://schemas.android.com/apk/res/android">
        <application android:label="ruflet_client">
            <activity android:name=".MainActivity" />
        </application>
    </manifest>
  XML

  def test_the_project_is_named_as_flutter_stores_its_directory
    builder = DummyBuilder.new
    FLUTTER_ASSET_NAMES.each do |name, stored|
      assert_equal stored, builder.send(:uri_path_segment_escape, name), name
    end

    Dir.mktmpdir do |root|
      FLUTTER_ASSET_NAMES.each do |name, stored|
        project = File.join(root, name)
        FileUtils.mkdir_p(project)
        Dir.chdir(project) do
          # Outside a UTF-8 locale Dir.pwd, and so the name, is BINARY.
          assert_equal name.b, builder.send(:self_contained_project_name).b
          assert_equal stored, builder.send(:self_contained_project_asset_name), name
        end
      end
    end
  end

  def test_native_configuration_names_the_stored_directory
    ["My Shop", "café", "Bob's App", "Tom & Jerry", "x[1]", "C# App"].each do |name|
      with_client(name) do |builder, client_dir, plist_buddy|
        stored = FLUTTER_ASSET_NAMES.fetch(name) { builder.send(:uri_path_segment_escape, name) }

        %w[ios macos].each do |platform|
          assert_equal stored, plist_string(File.join(client_dir, platform, "Runner", "Info.plist"), "RufletEmbeddedProject"),
                       "#{name}: #{platform} Info.plist"
        end
        manifest = File.read(File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml"))
        assert_equal [stored], manifest_values(manifest, "ruflet.runtime.project"), "#{name}: AndroidManifest.xml"
        assert_includes plist_buddy, "Add :RufletEmbeddedProject string #{builder.send(:plist_buddy_escape, stored)}"
      end
    end
    with_client("Bob's App") do |_builder, _client_dir, plist_buddy|
      assert_includes plist_buddy, "Add :RufletEmbeddedProject string Bob\\'s%20App"
    end
  end

  # configure_platform_autostart has no case for aab or ipa, so for
  # `ruflet build aab --self` and `ruflet build ipa --self` the runtime-mode
  # contributor's value is the one that ships.
  def test_an_app_bundle_and_an_ipa_name_the_stored_directory
    ["My Shop", "Tom & Jerry"].each do |name|
      with_client(name, platforms: %w[aab ipa]) do |_builder, client_dir, plist_buddy|
        stored = FLUTTER_ASSET_NAMES.fetch(name)
        manifest = File.read(File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml"))
        assert_equal [stored], manifest_values(manifest, "ruflet.runtime.project"), "#{name}: aab"
        assert_equal stored, plist_string(File.join(client_dir, "ios", "Runner", "Info.plist"), "RufletEmbeddedProject"),
                     "#{name}: ipa"
        assert_empty plist_buddy, "#{name}: no autostart step ran"
      end
    end
  end

  def test_names_flutter_stores_as_they_are_are_written_as_before
    UNCHANGED_NAMES.each do |name|
      with_client(name) do |_builder, client_dir, plist_buddy|
        %w[ios macos].each do |platform|
          content = File.read(File.join(client_dir, platform, "Runner", "Info.plist"))
          assert_includes content, "\t<key>RufletEmbeddedProject</key>\n\t<string>#{name}</string>", name
        end
        manifest = File.read(File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml"))
        assert_includes manifest, %(        <meta-data android:name="ruflet.runtime.project" android:value="#{name}" />), name
        # The exact PlistBuddy command the CLI ran before.
        assert_includes plist_buddy, "Add :RufletEmbeddedProject string #{name}"
        assert_includes plist_buddy, "Add :RufletRuntimeAutostart bool true"

        pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")))
        assert_equal ["assets/#{name}/"], pubspec.fetch("flutter").fetch("assets"), name
      end
    end
  end

  def test_an_ampersand_keeps_the_android_manifest_valid_xml
    require "rexml/document"

    with_client("Tom & Jerry") do |builder, client_dir, _plist_buddy|
      manifest_path = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
      manifest = File.read(manifest_path)
      document = REXML::Document.new(manifest)
      values = REXML::XPath.match(document, "//meta-data").to_h do |node|
        [node.attributes["android:name"], node.attributes["android:value"]]
      end
      assert_equal "Tom%20&%20Jerry", values.fetch("ruflet.runtime.project")
      assert_equal "true", values.fetch("ruflet.runtime.autostart")

      # An existing entry is replaced literally: a "\0" in the value is not a
      # back-reference to the entry it replaces.
      builder.send(:set_android_meta_data, manifest_path, "ruflet.runtime.project", "a\\0b")
      assert_equal ["a\\0b"], manifest_values(File.read(manifest_path), "ruflet.runtime.project")
    end
  end

  def test_plist_buddy_reads_back_each_value_it_is_given
    builder = DummyBuilder.new
    assert_equal "shop", builder.send(:plist_buddy_escape, "shop")
    assert_equal "true", builder.send(:plist_buddy_escape, "true")
    assert_equal "Bob\\'s%20App", builder.send(:plist_buddy_escape, "Bob's%20App")
    assert_equal "a\\ b\\\"c\\\\d", builder.send(:plist_buddy_escape, "a b\"c\\d")

    plist_buddy = "/usr/libexec/PlistBuddy"
    skip "PlistBuddy runs only on macOS" unless File.executable?(plist_buddy)

    Dir.mktmpdir do |dir|
      plist = File.join(dir, "Info.plist")
      # Unescaped, "Bob's" made Add fail and "Rock'n'Roll" was stored as
      # "RocknRoll".
      ["Bob's%20App", "Bob's", "Rock'n'Roll", "a b", "quo\"te", "back\\slash", "Tom%20&%20Jerry", "shop"].each do |value|
        File.write(plist, PLIST)
        builder.send(:set_plist_value, plist, "RufletEmbeddedProject", "string", value)
        read = IO.popen([plist_buddy, "-c", "Print :RufletEmbeddedProject", plist], err: File::NULL, &:read).chomp
        assert_equal value, read, value.inspect
      end
    end
  end

  def test_an_apostrophe_no_longer_removes_the_plist_key
    skip "PlistBuddy runs only on macOS" unless File.executable?("/usr/libexec/PlistBuddy")

    with_client("Bob's App", real_plist_buddy: true) do |_builder, client_dir, _plist_buddy|
      plist = File.join(client_dir, "ios", "Runner", "Info.plist")
      read = IO.popen(["/usr/libexec/PlistBuddy", "-c", "Print :RufletEmbeddedProject", plist], err: File::NULL, &:read)
      assert_equal "Bob's%20App", read.chomp
    end
  end

  def test_pubspec_entries_escape_only_what_flutter_misreads
    builder = DummyBuilder.new
    {
      "assets/shop/" => "assets/shop/",
      "assets/My Shop/" => "assets/My Shop/",
      "assets/café/lib/" => "assets/café/lib/",
      "assets/Bob's App/" => "assets/Bob's App/",
      "assets/x[1]/" => "assets/x[1]/",
      "assets/100%/" => "assets/100%/",
      "assets/C# App/" => "assets/C%23 App/",
      "assets/q?/" => "assets/q%3F/",
      "assets/50%25/" => "assets/50%2525/",
      "assets/back\\slash/" => "assets/back%5Cslash/"
    }.each do |entry, written|
      assert_equal written, builder.send(:pubspec_asset_entry, entry), entry
    end

    with_client("C# App") do |builder2, client_dir, _plist_buddy|
      pubspec_path = File.join(client_dir, "pubspec.yaml")
      rebuild = lambda do |seeded, self_contained:|
        data = YAML.safe_load(File.read(pubspec_path))
        data["flutter"]["assets"] = seeded
        File.write(pubspec_path, YAML.dump(data))
        Dir.chdir(File.dirname(File.dirname(client_dir))) do
          builder2.send(:sync_client_pubspec_for_runtime_mode, client_dir, self_contained: self_contained)
        end
        YAML.safe_load(File.read(pubspec_path)).fetch("flutter").fetch("assets")
      end

      # A rebuild replaces the entries an older CLI wrote unescaped,
      assert_equal ["assets/icon.png", "assets/C%23 App/"],
                   rebuild.call(["assets/C# App/", "assets/C# App/lib/", "assets/icon.png"], self_contained: true)
      # and the escaped ones this CLI wrote for a profile whose directories
      # are gone (full's vendor/bundle on a lite rebuild),
      assert_equal ["assets/icon.png", "assets/C%23 App/"],
                   rebuild.call(["assets/C%23 App/", "assets/C%23 App/vendor/bundle/", "assets/icon.png"],
                                self_contained: true)
      # and all of them when the app is rebuilt server-driven.
      assert_equal ["assets/icon.png"],
                   rebuild.call(["assets/C%23 App/", "assets/C%23 App/lib/", "assets/C# App/", "assets/icon.png"],
                                self_contained: false)
    end
  end

  def test_file_uris_keep_reserved_characters_in_the_path
    builder = DummyBuilder.new
    # Paths that worked before get the URI they got before.
    ["/Users/me/My Shop/café/build/client/.dart_tool/package_config.json",
     "/a/-_.!~*'()/;:@&=+$,/b c",
     "D:\\Work\\My App\\build\\client\\.dart_tool\\package_config.json"].each do |path|
      before = URI::DEFAULT_PARSER.escape(path.tr("\\", "/"))
      before = before.start_with?("/") ? "file://#{before}" : "file:///#{before}"
      assert_equal before, builder.send(:file_uri_for, path), path
    end

    assert_equal "file:///Apps%20%5B2026%5D/What%3F/a%7Bb%7D/%23x/package_config.json",
                 builder.send(:file_uri_for, "/Apps [2026]/What?/a{b}/#x/package_config.json")
    uri = URI.join(builder.send(:file_uri_for, "/Apps [2026]/What?/x/.dart_tool/package_config.json"), "../pkg")
    assert_equal "/Apps [2026]/What?/x/pkg", builder.send(:path_from_file_uri, uri)
  end

  def test_local_packages_verify_under_any_project_path
    ["plain", "Apps [2026]", "What?", "proj{1}", "café", "My Shop", "C# x", "100%"].each do |folder|
      Dir.mktmpdir do |tmp|
        client_dir = File.join(tmp, folder, "shop", "build", "client")
        package = File.join(client_dir, "ruflet_packages", "ruflet")
        FileUtils.mkdir_p(package)
        File.write(File.join(package, "pubspec.yaml"), "name: ruflet\n")
        FileUtils.mkdir_p(File.join(client_dir, ".dart_tool"))
        File.write(
          File.join(client_dir, ".dart_tool", "package_config.json"),
          JSON.generate("configVersion" => 2,
                        "packages" => [{ "name" => "ruflet", "rootUri" => "../ruflet_packages/ruflet", "packageUri" => "lib/" }])
        )
        builder = DummyBuilder.new
        builder.instance_variable_set(:@ruflet_selected_flutter_extension_packages, [])

        ok = nil
        out, err = capture_io { ok = builder.send(:validate_local_ruflet_packages, client_dir) }
        assert ok, "#{folder}: #{err}"
        assert_includes out, "Verified 1 local Ruflet engine, extension and vendor packages"
      end
    end
  end

  def test_globbed_build_steps_see_the_project_under_a_path_with_glob_characters
    Dir.mktmpdir do |tmp|
      client_dir = File.join(tmp, "Apps [2026]", "proj{1}", "build", "client")

      # The local_auth activity swap.
      activity = File.join(client_dir, "android", "app", "src", "main", "kotlin", "com", "acme", "shop", "MainActivity.kt")
      FileUtils.mkdir_p(File.dirname(activity))
      File.write(activity, "package com.acme.shop\n\nimport io.flutter.embedding.android.FlutterActivity\n\n" \
                           "class MainActivity : FlutterActivity()\n")
      builder = DummyBuilder.new
      builder.send(:apply_android_activity_base, client_dir, ["local_auth"])
      assert_includes File.read(activity), "class MainActivity : FlutterFragmentActivity()"

      # The lite precompile compiles every Ruby file.
      project = File.join(client_dir, "assets", "proj{1}")
      FileUtils.mkdir_p(File.join(project, "lib"))
      File.write(File.join(project, "main.rb"), "puts 1\n")
      File.write(File.join(project, "lib", "helper.rb"), "puts 2\n")
      compiled = []
      builder.define_singleton_method(:embedded_mrbc_path) { "/fake/mrbc" }
      builder.define_singleton_method(:run_external_command) do |_env, *cmd, chdir:, unbundled: false|
        _compiler, _debug, _flag, output, source = cmd
        compiled << source.delete_prefix("#{chdir}/")
        File.write(output, "mrb\n")
        true
      end
      assert builder.send(:precompile_lite_runtime_project, project)
      assert_equal %w[lib/helper.rb main.rb], compiled
      assert_path_exists File.join(project, "main.mrb")
      refute_path_exists File.join(project, "main.rb")

      # The runtime manifest's cache key covers the same files as under a
      # plain path.
      builder.send(:write_embedded_runtime_manifest, Pathname.new(tmp), project, profile: :lite, platform: "apk")
      plain = File.join(tmp, "plain")
      FileUtils.cp_r(project, plain)
      FileUtils.rm_f(File.join(plain, ".ruflet-runtime.json"))
      builder.send(:write_embedded_runtime_manifest, Pathname.new(tmp), plain, profile: :lite, platform: "apk")
      key = ->(dir) { JSON.parse(File.read(File.join(dir, ".ruflet-runtime.json"))).fetch("cache_key") }
      assert_equal key.call(plain), key.call(project)
      refute_equal Digest::SHA256.hexdigest(""), key.call(project)

      # The full profile's bundle cache is pruned and its ruflet_server checked.
      bundle = File.join(client_dir, ".ruflet", "full-bundle", "key", "vendor", "bundle")
      FileUtils.mkdir_p(File.join(bundle, "ruby", "3.4.0", "cache"))
      FileUtils.mkdir_p(File.join(bundle, "ruby", "3.4.0", "gems", "ruflet_server-0.0.1", "lib"))
      builder.send(:prune_full_runtime_bundle_cache, bundle)
      refute_path_exists File.join(bundle, "ruby", "3.4.0", "cache")
      err = capture_io { refute builder.send(:validate_full_runtime_in_process_transport, bundle) }.last
      assert_includes err, "does not support port-free --self --full builds"
    end
  end

  def test_stale_ios_assets_are_cleared_under_the_stored_name
    ["My Shop", "a*b", "shop"].each do |name|
      Dir.mktmpdir do |tmp|
        project = File.join(tmp, "Apps [2026]", name)
        client_dir = File.join(project, "build", "client")
        assets = File.join(client_dir, "build", "ios", "iphoneos", "Runner.app", "Frameworks", "App.framework",
                           "flutter_assets", "assets")
        stored = File.join(assets, FLUTTER_ASSET_NAMES.fetch(name, name), "vendor", "stale.rb")
        other = File.join(assets, "aXb", "main.rb")
        [stored, other].each do |path|
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, "stale\n")
        end

        Dir.chdir(project) { DummyBuilder.new.send(:clear_stale_platform_outputs, client_dir, "ios") }

        refute_path_exists File.dirname(File.dirname(stored)), name
        assert_path_exists other, "#{name}: a project's name is not a glob pattern"
      end
    end
  end

  def test_rails_views_are_read_under_a_path_with_glob_characters
    Dir.mktmpdir do |tmp|
      project = File.join(tmp, "Apps [2026]")
      views = File.join(project, "app", "views", "ruflet")
      FileUtils.mkdir_p(File.join(project, "config"))
      FileUtils.mkdir_p(views)
      File.write(File.join(project, "config", "application.rb"), "# rails\n")
      File.write(File.join(views, "main.rb"), "page.add(text(\"hi\"))\n")

      assert_equal [File.join(views, "main.rb")], Ruflet::CLI::TemplateSurface.ruby_files(project)
    end
  end

  # The macOS (*.app) and Windows (*.exe) lookups, each run as on that host.
  def test_the_desktop_client_is_found_under_a_path_with_glob_characters
    url = "http://127.0.0.1:8550"
    Dir.mktmpdir do |tmp|
      root = File.join(tmp, "Apps [2026]", "ruflet_client")
      macos_dir = File.join(root, "build", "macos", "Build", "Products", "Release", "Shop.app", "Contents", "MacOS")
      windows_dir = File.join(root, "build", "windows", "x64", "runner", "Release")
      [macos_dir, windows_dir].each { |dir| FileUtils.mkdir_p(dir) }
      app = File.join(macos_dir, "Shop")
      exe = File.join(windows_dir, "Shop.exe")
      [app, exe].each do |path|
        File.write(path, "#!/bin/sh\n")
        FileUtils.chmod(0o755, path)
      end

      { "darwin25" => app, "mingw32" => exe }.each do |host_os, expected|
        command = with_host_os(host_os) { DummyRunner.new.send(:detect_desktop_client_command, url, root: root) }
        assert_equal [expected, url], command, host_os
      end
    end
  end

  private

  def with_host_os(host_os)
    saved = RbConfig::CONFIG["host_os"]
    RbConfig::CONFIG["host_os"] = host_os
    yield
  ensure
    RbConfig::CONFIG["host_os"] = saved
  end

  # A client dir at <tmp>/Apps [2026]/<name>/build/client with the
  # template's Info.plist and AndroidManifest.xml, configured for a
  # self-contained build of each platform the way `ruflet build` does: the
  # runtime-mode contributor first, then the autostart step right before
  # Flutter runs. PlistBuddy is recorded rather than run unless
  # real_plist_buddy is set.
  def with_client(name, platforms: %w[ios macos apk], real_plist_buddy: false)
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "Apps [2026]", name))
      builder = DummyBuilder.new
      plist_buddy = []
      unless real_plist_buddy
        builder.define_singleton_method(:system) do |*args, **_options|
          plist_buddy << args[2] if args.first == "/usr/libexec/PlistBuddy"
          true
        end
      end

      client_dir = nil
      Dir.chdir(File.join(tmp, "Apps [2026]", name)) do
        # Every path comes from Dir.pwd, as in a real build, so that it has
        # the encoding the CLI's own paths have (BINARY outside a UTF-8
        # locale) and File.join can combine them.
        project = Dir.pwd
        client_dir = File.join(project, "build", "client")
        %w[ios macos].each do |platform|
          path = File.join(client_dir, platform, "Runner", "Info.plist")
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, PLIST)
        end
        manifest = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
        FileUtils.mkdir_p(File.dirname(manifest))
        File.write(manifest, MANIFEST)
        File.write(File.join(client_dir, "pubspec.yaml"), "name: ruflet_client\nflutter:\n  assets: []\n")
        packaged = File.join(client_dir, "assets", File.basename(project))
        FileUtils.mkdir_p(packaged)
        File.write(File.join(packaged, "main.rb"), "puts 1\n")
        File.write(File.join(project, "main.rb"), "puts 1\n")

        builder.send(:sync_client_pubspec_for_runtime_mode, client_dir, self_contained: true)
        platforms.each do |platform|
          builder.send(:configure_native_apple_runtime, client_dir, platform: platform, self_contained: true)
          builder.send(:configure_android_runtime, client_dir, platform: platform, self_contained: true)
        end
        platforms.each { |platform| builder.send(:configure_platform_autostart, client_dir, platform) }
      end
      yield builder, client_dir, plist_buddy
    end
  end

  def plist_string(path, key)
    content = File.read(path)
    raw = content[%r{<key>#{Regexp.escape(key)}</key>\s*<string>(.*?)</string>}m, 1]
    raw && unescape_xml(raw)
  end

  def manifest_values(content, name)
    content.scan(/<meta-data android:name="#{Regexp.escape(name)}" android:value="([^"]*)"/).flatten.map { |raw| unescape_xml(raw) }
  end

  def unescape_xml(raw)
    raw.gsub("&lt;", "<").gsub("&gt;", ">").gsub("&quot;", '"').gsub("&apos;", "'").gsub("&amp;", "&")
  end
end
