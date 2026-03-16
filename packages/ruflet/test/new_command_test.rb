# frozen_string_literal: true

require_relative "test_helper"

class RufletCliNewCommandTest < Minitest::Test
  def test_command_new_creates_project_scaffold
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        out = StringIO.new
        original_stdout = $stdout
        $stdout = out

        cli_singleton = Ruflet::CLI.singleton_class
        had_method = cli_singleton.private_method_defined?(:copy_ruflet_client_template) || cli_singleton.method_defined?(:copy_ruflet_client_template)
        original_method = Ruflet::CLI.method(:copy_ruflet_client_template) if had_method

        cli_singleton.send(:define_method, :copy_ruflet_client_template) { |_root| nil }
        cli_singleton.send(:private, :copy_ruflet_client_template)

        result = Ruflet::CLI.command_new(["demo_app"])

        assert_equal 0, result
        assert File.exist?(File.join(dir, "demo_app", "main.rb"))
        assert File.exist?(File.join(dir, "demo_app", "Gemfile"))
        assert File.exist?(File.join(dir, "demo_app", "README.md"))
        assert File.exist?(File.join(dir, "demo_app", "ruflet.yaml"))
        refute File.exist?(File.join(dir, "demo_app", ".bundle", "config"))
      ensure
        $stdout = original_stdout

        if had_method
          cli_singleton.send(:define_method, :copy_ruflet_client_template, original_method)
          cli_singleton.send(:private, :copy_ruflet_client_template)
        else
          cli_singleton.send(:remove_method, :copy_ruflet_client_template)
        end
      end
    end
  end

  def test_prune_client_manifest_keeps_only_selected_extensions
    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))

      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            flet:
              git:
                url: https://github.com/flet-dev/flet.git
            flet_camera:
              git:
                url: https://github.com/flet-dev/flet.git
            flet_video:
              git:
                url: https://github.com/flet-dev/flet.git
        YAML
      )

      File.write(
        File.join(client_dir, "lib", "main.dart"),
        <<~DART
          import 'package:flet/flet.dart';
          import 'package:flet_camera/flet_camera.dart' as ruflet_camera;
          import 'package:flet_video/flet_video.dart' as ruflet_video;

          final extensions = <FletExtension>[
            ruflet_camera.Extension(),
            ruflet_video.Extension(),
          ];
        DART
      )

      Ruflet::CLI.send(:apply_client_manifest!, client_dir, ["flet_camera"], ["ruflet_camera"])

      pruned_pubspec = File.read(File.join(client_dir, "pubspec.yaml"))
      pruned_main = File.read(File.join(client_dir, "lib", "main.dart"))

      assert_includes pruned_pubspec, "flet_camera:"
      refute_includes pruned_pubspec, "flet_video:"
      assert_includes pruned_main, "ruflet_camera.Extension()"
      refute_includes pruned_main, "ruflet_video.Extension()"
    end
  end
end
