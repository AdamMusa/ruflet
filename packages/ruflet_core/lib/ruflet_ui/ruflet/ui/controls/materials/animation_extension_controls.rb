# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AnimationExtensionControl < Ruflet::Control
          KEYWORDS = [].freeze

          def initialize(type:, id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: type, id: id, **compact)
          end
        end

        class LottieControl < AnimationExtensionControl
          WIRE = "Lottie".freeze
          def initialize(id: nil, **props) = super(type: "lottie", id: id, **props)
        end

        class RiveControl < AnimationExtensionControl
          WIRE = "Rive".freeze
          def initialize(id: nil, **props) = super(type: "rive", id: id, **props)
        end
      end
    end
  end
end
