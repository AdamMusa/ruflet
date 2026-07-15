# frozen_string_literal: true

# Verifies that the packaged VM archive and generic bootstrap expose the
# preloaded Ruflet gems through the same require entry point applications use.
require "ruflet"

raise "unexpected Ruflet version: #{Ruflet::VERSION}" unless Ruflet::VERSION == "0.0.19"
raise "Ruflet::Page is unavailable" unless Ruflet.const_defined?(:Page)
raise "show_snackbar is unavailable" unless Ruflet::Page.method_defined?(:show_snackbar)

puts "packaged Ruflet #{Ruflet::VERSION} gem loaded"
