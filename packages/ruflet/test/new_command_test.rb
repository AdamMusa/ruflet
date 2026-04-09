# frozen_string_literal: true

require_relative "test_helper"

class RufletCliNewCommandTest < Minitest::Test
  def test_command_new_creates_project_scaffold
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        out = StringIO.new
        original_stdout = $stdout
        $stdout = out

        result = Ruflet::CLI.command_new(["demo_app"])

        assert_equal 0, result
        assert File.exist?(File.join(dir, "demo_app", "main.rb"))
        assert File.exist?(File.join(dir, "demo_app", "Gemfile"))
        assert File.exist?(File.join(dir, "demo_app", "README.md"))
        assert File.exist?(File.join(dir, "demo_app", "ruflet.yaml"))
        refute File.exist?(File.join(dir, "demo_app", "ruflet_client"))
        refute File.exist?(File.join(dir, "demo_app", ".bundle", "config"))
      ensure
        $stdout = original_stdout
      end
    end
  end

  def test_copy_ruflet_client_template_prefers_flutter_template
    Dir.mktmpdir do |dir|
      target_root = File.join(dir, "demo")
      FileUtils.mkdir_p(target_root)

      Ruflet::CLI.send(:copy_ruflet_client_template, target_root)

      client_dir = File.join(target_root, "build", ".ruflet", "client")
      assert File.directory?(client_dir)
      assert File.file?(File.join(client_dir, "assets", "main.rb"))
      assert File.file?(File.join(client_dir, "lib", "main.dart"))
      assert File.file?(File.join(client_dir, "lib", "main.self.dart"))
      assert File.file?(File.join(client_dir, "lib", "main.server.dart"))
    end
  end

  def test_copy_ruflet_client_template_uses_cached_template_when_repo_template_missing
    Dir.mktmpdir do |dir|
      target_root = File.join(dir, "demo")
      cached_template = File.join(dir, "cached_template")
      FileUtils.mkdir_p(File.join(cached_template, "lib"))
      FileUtils.mkdir_p(File.join(cached_template, "assets"))
      File.write(File.join(cached_template, "assets", "main.rb"), "puts 'hi'\n")
      File.write(File.join(cached_template, "lib", "main.dart"), "void main() {}\n")
      File.write(File.join(cached_template, "lib", "main.self.dart"), "void main() {}\n")
      File.write(File.join(cached_template, "lib", "main.server.dart"), "void main() {}\n")
      FileUtils.mkdir_p(target_root)

      cli_singleton = Ruflet::CLI.singleton_class
      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      cli_singleton.send(:define_method, :resolve_ruflet_client_template_root) { cached_template }
      cli_singleton.send(:private, :resolve_ruflet_client_template_root)

      Ruflet::CLI.send(:copy_ruflet_client_template, target_root)

      client_dir = File.join(target_root, "build", ".ruflet", "client")
      assert File.directory?(client_dir)
      assert File.file?(File.join(client_dir, "assets", "main.rb"))
      assert File.file?(File.join(client_dir, "lib", "main.server.dart"))
    ensure
      cli_singleton.send(:define_method, :resolve_ruflet_client_template_root, original_method)
      cli_singleton.send(:private, :resolve_ruflet_client_template_root)
    end
  end
end
