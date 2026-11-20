# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # One `ruflet build` as the contributors see it: what was asked for, and
      # what earlier contributors produced for later steps. app_identity sets
      # `metadata`, extensions sets `extension_keys` and assets sets
      # `asset_flags`, which the Flutter steps after the contributors read.
      Context = Struct.new(
        :client_dir, :platform, :tools, :config, :self_contained, :verbose,
        :metadata, :extension_keys, :asset_flags,
        keyword_init: true
      )
    end
  end
end
