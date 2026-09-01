# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AdControl < Ruflet::Control
          def initialize(type:, id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: type, id: id, **compact)
          end
        end

        class BannerAdControl < AdControl
          WIRE = "BannerAd".freeze

          def initialize(id: nil, **props)
            super(type: "banner_ad", id: id, **props)
          end
        end

        class InterstitialAdControl < AdControl
          WIRE = "InterstitialAd".freeze

          def initialize(id: nil, **props)
            super(type: "interstitial_ad", id: id, **props)
          end

          def show(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "show", timeout: timeout, on_result: on_result)
          end
        end

        class NativeAdControl < AdControl
          WIRE = "NativeAd".freeze

          def initialize(id: nil, **props)
            super(type: "native_ad", id: id, **props)
          end
        end
      end
    end
  end
end
