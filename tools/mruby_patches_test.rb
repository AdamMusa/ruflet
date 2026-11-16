# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../ruby_runtime/vm/patches/mruby_patches"

class MrubyPatchesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  BUILD_CONFIGS = Dir[File.join(ROOT, "ruby_runtime/vm/build_config/*.rb")].sort
  METHOD_MISSING_PATCH = File.join(RufletMrubyPatches::DIR, "0001-Fixed-heap-buffer-overflow-in-method_missing.patch")

  def test_every_build_config_applies_the_patches
    refute_empty BUILD_CONFIGS
    BUILD_CONFIGS.each do |config|
      source = File.read(config)

      assert_includes source, 'require_relative "../patches/mruby_patches"', config
      assert_includes source, "RufletMrubyPatches.apply(MRUBY_ROOT)", config
    end
  end

  def test_carries_only_the_method_missing_fix
    assert_equal [METHOD_MISSING_PATCH], RufletMrubyPatches.patches

    patch = File.read(METHOD_MISSING_PATCH)
    assert_includes patch, "(cherry picked from commit 550d10adb76a1bde1954ea78e1b8b5451c74cec3)"
    assert_equal ["src/vm.c"], patch.scan(%r{^diff --git a/(\S+)}).flatten
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
