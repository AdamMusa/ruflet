# frozen_string_literal: true

# Upstream mruby fixes carried on top of the pinned third_party/mruby.
#
# The gitlink pins mruby 449627d. Moving the pin to pick up one fix also picks
# up unrelated VM behaviour changes, so a fix the pin predates is kept here as
# the upstream commit's own patch (mruby/<n>-*.patch, oldest first) and applied
# to the mruby tree before it compiles.
#
# Every config in ../build_config applies them as minirake loads it, which
# covers tools/build_apple_vm_artifacts.sh, tools/build_vm_artifacts.sh and
# rake run by hand. Android's CMake compiles third_party/mruby/src directly,
# but only from a tree whose host_vm build has run, and that build applies
# them; `--check` verifies such a tree.
#
# Applying is idempotent: a patch the tree already has is left alone, whether
# an earlier build applied it or the pin itself contains it. A patch that
# neither applies cleanly nor is already there stops the build. When the pin
# moves, delete the patches the new pin contains.
#
#   ruby ruby_runtime/vm/patches/mruby_patches.rb [--check] [MRUBY_DIR]
module RufletMrubyPatches
  class Error < StandardError; end

  DIR = File.expand_path("mruby", __dir__)

  module_function

  def patches
    Dir[File.join(DIR, "*.patch")].sort
  end

  # :applied when the tree already has the patch, :pending when it applies.
  def status(root, patch)
    return :applied if git_apply(root, "--check", "--reverse", patch)
    return :pending if git_apply(root, "--check", patch)

    raise Error, "#{File.basename(patch)} neither applies to nor is already applied in #{root}. " \
                 "If third_party/mruby moved off 449627d, delete the patches the new pin contains."
  end

  def apply(root)
    patches.each do |patch|
      next if status(root, patch) == :applied

      git_apply(root, patch) or raise Error, "could not apply #{File.basename(patch)} to #{root}"
      warn "ruflet: applied mruby patch #{File.basename(patch)}"
    end
  end

  def pending(root)
    patches.select { |patch| status(root, patch) == :pending }
  end

  # The ceiling keeps git from treating an enclosing checkout (this repository,
  # when third_party/mruby is not a clone of its own) as the tree to patch.
  def git_apply(root, *args)
    root = File.realpath(root)
    system({ "GIT_CEILING_DIRECTORIES" => File.dirname(root) },
           "git", "-C", root, "apply", *args, out: File::NULL, err: File::NULL)
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  root = ARGV.first || File.expand_path("../../third_party/mruby", __dir__)
  begin
    if check
      missing = RufletMrubyPatches.pending(root)
      missing.each { |patch| warn "not applied: #{File.basename(patch)}" }
      exit(missing.empty? ? 0 : 1)
    end
    RufletMrubyPatches.apply(root)
  rescue RufletMrubyPatches::Error, SystemCallError => e
    warn e.message
    exit 2
  end
end
