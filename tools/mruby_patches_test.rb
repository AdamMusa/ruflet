# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../ruby_runtime/vm/patches/mruby_patches"

class MrubyPatchesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  BUILD_CONFIGS = Dir[File.join(ROOT, "ruby_runtime/vm/build_config/*.rb")].sort
  METHOD_MISSING_PATCH = File.join(RufletMrubyPatches::DIR, "0001-Fixed-heap-buffer-overflow-in-method_missing.patch")

  # Loads each config as minirake does, but against stand-ins for MRuby
  # and RufletMrubyPatches, so a hook that is commented out or never reached
  # fails here.
  def test_every_build_config_applies_the_patches
    refute_empty BUILD_CONFIGS
    BUILD_CONFIGS.each do |config|
      assert_match(/^require_relative "..\/patches\/mruby_patches"$/, File.read(config), config)

      assert_equal [[:apply, "/mruby/root"], :build], load_build_config(config), config
    end
  end

  def test_carries_only_the_method_missing_fix
    assert_equal [METHOD_MISSING_PATCH], RufletMrubyPatches.patches

    patch = File.read(METHOD_MISSING_PATCH)
    assert_includes patch, "(cherry picked from commit 550d10adb76a1bde1954ea78e1b8b5451c74cec3)"
    assert_equal ["src/vm.c"], patch.scan(%r{^diff --git a/(\S+)}).flatten
    assert_equal 1, patch.scan(/^@@ /).size

    # Upstream 550d10a, line for line.
    changed = patch.lines(chomp: true).grep(/^[-+](?![-+])/)
    assert_equal [
      "-    argv[1] = argv[ci->n];",
      "+    if (ci->n != CALL_MAXARGS) {",
      "+      argv[1] = argv[ci->n];    /* keyword arguments */",
      "+    }"
    ], changed
  end

  def test_applies_once_and_then_leaves_the_tree_alone
    Dir.mktmpdir do |mruby|
      write_vm_c(mruby, pre_image)

      assert_equal :pending, RufletMrubyPatches.status(mruby, METHOD_MISSING_PATCH)
      capture_io { RufletMrubyPatches.apply(mruby) }
      patched = File.read(File.join(mruby, "src/vm.c"))
      assert_includes patched, "if (ci->n != CALL_MAXARGS) {"

      assert_equal :applied, RufletMrubyPatches.status(mruby, METHOD_MISSING_PATCH)
      _out, err = capture_io { RufletMrubyPatches.apply(mruby) }
      assert_empty err
      assert_equal patched, File.read(File.join(mruby, "src/vm.c"))
      assert_empty RufletMrubyPatches.pending(mruby)
    end
  end

  def test_a_tree_the_patch_does_not_fit_stops_the_build
    Dir.mktmpdir do |mruby|
      write_vm_c(mruby, "static void\nprepare_missing(void)\n{\n}\n")

      error = assert_raises(RufletMrubyPatches::Error) { RufletMrubyPatches.apply(mruby) }
      assert_includes error.message, "delete the patches the new pin contains"
    end
  end

  def test_a_missing_git_is_reported_as_such
    Dir.mktmpdir do |mruby|
      write_vm_c(mruby, pre_image)

      Dir.mktmpdir do |no_git|
        original = ENV.fetch("PATH")
        ENV["PATH"] = no_git
        error = assert_raises(RufletMrubyPatches::Error) { RufletMrubyPatches.apply(mruby) }
        assert_includes error.message, "git is required to apply ruby_runtime/vm/patches"
      ensure
        ENV["PATH"] = original
      end

      assert_equal pre_image, File.read(File.join(mruby, "src/vm.c"))
    end
  end

  def test_the_command_line_reports_a_missing_git
    Dir.mktmpdir do |mruby|
      write_vm_c(mruby, pre_image)

      Dir.mktmpdir do |no_git|
        script = File.expand_path("../mruby_patches.rb", RufletMrubyPatches::DIR)
        _out, err, status = Open3.capture3({ "PATH" => no_git }, RbConfig.ruby, script, mruby)

        assert_equal 2, status.exitstatus
        assert_includes err, "git is required to apply ruby_runtime/vm/patches"
      end
    end
  end

  def test_an_enclosing_checkout_is_not_patched_instead
    Dir.mktmpdir do |outer|
      system("git", "init", "-q", outer, exception: true)
      mruby = File.join(outer, "third_party/mruby")
      write_vm_c(mruby, pre_image)
      write_vm_c(outer, pre_image)

      capture_io { RufletMrubyPatches.apply(mruby) }

      assert_includes File.read(File.join(mruby, "src/vm.c")), "if (ci->n != CALL_MAXARGS) {"
      assert_equal pre_image, File.read(File.join(outer, "src/vm.c"))
    end
  end

  # Runs where a populated mruby is at hand (RUFLET_MRUBY, as the build
  # scripts take it, or this checkout's third_party/mruby).
  def test_fits_the_pinned_mruby
    mruby = ENV.fetch("RUFLET_MRUBY", File.join(ROOT, "ruby_runtime/third_party/mruby"))
    skip "no populated mruby at #{mruby}" unless File.file?(File.join(mruby, "src/vm.c"))

    assert_includes %i[pending applied], RufletMrubyPatches.status(mruby, METHOD_MISSING_PATCH)
  end

  private

  # Returns what the config did, in order: [:apply, root] for each
  # RufletMrubyPatches.apply and :build for each MRuby build it declares.
  def load_build_config(config)
    events = []
    build = Class.new { define_singleton_method(:new) { |*_args, &_block| events << :build } }
    mruby = Module.new
    mruby.const_set(:Build, build)
    mruby.const_set(:CrossBuild, build)
    patches = Module.new
    patches.define_singleton_method(:apply) { |root| events << [:apply, root] }

    sandbox = Module.new
    sandbox.const_set(:MRUBY_ROOT, "/mruby/root")
    sandbox.const_set(:MRuby, mruby)
    sandbox.const_set(:RufletMrubyPatches, patches)

    env = { "RUFLET_VM_ARCH" => "arm64", "RUFLET_IOS_SDK" => "iphonesimulator", "RUFLET_IOS_ARCH" => "arm64" }
    saved = env.keys.to_h { |key| [key, ENV[key]] }
    begin
      ENV.update(env)
      load(config, sandbox)
    ensure
      ENV.update(saved)
    end
    events
  end

  # The patch's own context and removed lines, i.e. the code it expects.
  def pre_image
    hunk = File.read(METHOD_MISSING_PATCH).split(/^@@.*\n/, 2).last
    body = hunk.lines.take_while { |line| line.start_with?(" ", "-", "+") }
    "/* lines before */\n" + body.filter_map { |line| line[1..] unless line.start_with?("+") }.join
  end

  def write_vm_c(mruby, contents)
    FileUtils.mkdir_p(File.join(mruby, "src"))
    File.write(File.join(mruby, "src/vm.c"), contents)
  end
end
