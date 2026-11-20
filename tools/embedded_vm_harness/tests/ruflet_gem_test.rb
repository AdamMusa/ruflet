# frozen_string_literal: true

# Verifies that the packaged VM archive and generic bootstrap expose the
# preloaded Ruflet gems through the same require entry point applications use.
require "ruflet"

# The VM compiles packages/ruflet_core into the archive, so its version must be
# the one in this checkout. A mismatch means the archive under test was built
# from other sources -- for a release, that it was not rebuilt after the bump.
# Read from the source rather than pinned here, where it went stale at 0.0.22.
version_file = File.expand_path("../../../../packages/ruflet_core/lib/ruflet/version.rb", __FILE__)
expected = File.read(version_file).split('VERSION = "')[1].split('"')[0]
unless Ruflet::VERSION == expected
  raise "unexpected Ruflet version: #{Ruflet::VERSION} (sources are #{expected})"
end
raise "Ruflet::Page is unavailable" unless Ruflet.const_defined?(:Page)
raise "show_snackbar is unavailable" unless Ruflet::Page.method_defined?(:show_snackbar)

puts "packaged Ruflet #{Ruflet::VERSION} gem loaded"
