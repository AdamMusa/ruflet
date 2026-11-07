# frozen_string_literal: true

require "set"

# The lists below are read from ruflet_core's control registry. transformer.rb
# does not need ruflet_core to load (it did not on 0.0.23 either), so a
# program can require the HTML DSL before ruflet_core and read these constants
# before loading it. Load it here in that case only, so a copy that is already
# loaded is never loaded a second time.
unless defined?(::Ruflet::UI::ControlFactory::CLASS_MAP) && defined?(::Ruflet::UI::ServiceTypes)
  require "ruflet_core"
end

module Ruflet
  module Rails
    module HtmlDsl
      # Autoloaded by transformer.rb the first time Transformer::SERVICE_TAGS
      # or Transformer::SERVICE_TYPES is read. Both are deprecated: call
      # Transformer.service_tag?(tag), which is what the transformer uses.
      class Transformer
        # The list ruflet_rails 0.0.23 wrote out by hand, in its order.
        legacy_tags = %w[
          audio audio-recorder barometer battery clipboard connectivity
          file-picker flashlight geolocator gyroscope accelerometer magnetometer
          haptic-feedback permission-handler screen-brightness secure-storage
          shake-detector share shared-preferences storage-paths url-launcher
          user-accelerometer wakelock semantics-service
        ]

        # Every registered name that mounts as a service, read now rather than
        # when transformer.rb loaded, so extensions registered since are in it.
        factory = ::Ruflet::UI::ControlFactory
        service_names = (factory::CLASS_MAP.keys + factory::EXTENSION_CLASS_MAP.keys)
                        .map(&:to_s)
                        .uniq
                        .select { |name| service_tag?(name.tr("_", "-")) }

        # SERVICE_TAGS names each service once, as 0.0.23 did. The 0.0.23
        # entries come first, in their order, and the services added since
        # (`window`, `interstitial-ad`, an extension's tag) follow in registry
        # order. The registry also has a compact spelling for most services
        # (`filepicker` next to `file_picker`); service_tag? accepts those, but
        # they would make each such service appear twice, so they are not tags.
        tags = legacy_tags.select { |tag| service_tag?(tag) }
        listed = tags.map { |tag| tag.delete("-") }
        service_names.group_by { |name| name.delete("_") }.each do |compact, spellings|
          next if listed.include?(compact)

          listed << compact
          tags << spellings.max_by { |name| name.count("_") }.tr("_", "-")
        end

        # SERVICE_TYPES is what 0.0.23's transformer checked a tag against
        # (`SERVICE_TYPES.include?(tag.tr("-", "_"))`), so it keeps every
        # registered spelling service_tag? accepts: SERVICE_TAGS in underscored
        # form, in the same order, then the compact spellings.
        types = tags.map { |tag| tag.tr("-", "_") } + service_names

        SERVICE_TAGS = tags.map(&:freeze).freeze
        SERVICE_TYPES = types.map(&:freeze).to_set.freeze
        # Deprecated here, after the assignment, and not next to the autoload
        # in transformer.rb: a constant flagged before its autoload has run
        # warns twice on the first read (checked on Ruby 3.2 and 4.0), and
        # flagged here it warns once, like any other deprecated constant.
        deprecate_constant :SERVICE_TAGS, :SERVICE_TYPES
      end
    end
  end
end
