# frozen_string_literal: true

# Verify the exact packaged-runtime path used by application code: the mrbgem
# is already initialized before the generic bootstrap handles `require`.
require "ruflet_record"

unless RufletRecord::VERSION == "0.0.1"
  raise "unexpected RufletRecord version: #{RufletRecord::VERSION}"
end
raise "RufletRecord::Base is unavailable" unless RufletRecord.const_defined?(:Base)
raise "native SQLite is unavailable" unless RufletRecord.const_defined?(:NativeSQLite)

puts "packaged RufletRecord #{RufletRecord::VERSION} gem loaded"
