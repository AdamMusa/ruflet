# frozen_string_literal: true

# Verify the exact packaged-runtime path used by application code: the mrbgem
# is already initialized before the generic bootstrap handles `require`.
require "ruflet_record"

# Compared with the source version rather than a pinned literal, which went
# stale at 0.0.1; see ruflet_gem_test.rb.
version_file = File.expand_path("../../../../packages/ruflet_record/lib/ruflet_record/version.rb", __FILE__)
expected = File.read(version_file).split('VERSION = "')[1].split('"')[0]
unless RufletRecord::VERSION == expected
  raise "unexpected RufletRecord version: #{RufletRecord::VERSION} (sources are #{expected})"
end
raise "RufletRecord::Base is unavailable" unless RufletRecord.const_defined?(:Base)
raise "native SQLite is unavailable" unless RufletRecord.const_defined?(:NativeSQLite)

puts "packaged RufletRecord #{RufletRecord::VERSION} gem loaded"
