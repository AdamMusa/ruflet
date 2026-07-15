# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Rive control — parity with Flet's Rive extension
        # (https://flet.dev/docs/controls/rive/). Renders a Rive
        # (https://rive.app) animation from a `.riv` file.
        #
        # Properties: src, placeholder, artboard, alignment, enable_antialiasing,
        #   use_artboard_size, fit, speed_multiplier, animations, state_machines,
        #   headers, clip_rect, plus the usual layout props.
        # No events or methods — playback is driven by `animations` /
        #   `state_machines` and `speed_multiplier`.
        #
        # `src` is required and may be a network URL (e.g.
        # "https://cdn.rive.app/animations/vehicles.riv") or a bundled asset path.
        #
        # Note: the Flet API names the artboard property `artboard`, but the
        # underlying renderer reads `art_board` / `use_art_board_size` on the wire.
        # Both spellings are accepted here and normalized to the wire keys.
        class RiveControl < Ruflet::Control
          TYPE = "Rive".freeze
          WIRE = "Rive".freeze

          def initialize(id: nil, adaptive: nil, alignment: nil, animate_offset: nil,
                         animate_opacity: nil, animate_position: nil, animate_rotation: nil,
                         animate_scale: nil, animations: nil, art_board: nil, artboard: nil,
                         aspect_ratio: nil, badge: nil, bottom: nil, clip_rect: nil, col: nil,
                         data: nil, disabled: nil, enable_antialiasing: nil, expand: nil,
                         expand_loose: nil, fit: nil, headers: nil, height: nil, key: nil,
                         left: nil, offset: nil, opacity: nil, placeholder: nil, right: nil,
                         rotate: nil, rtl: nil, scale: nil, speed_multiplier: nil, src: nil,
                         state_machines: nil, tooltip: nil, top: nil, use_art_board_size: nil,
                         use_artboard_size: nil, visible: nil, width: nil)
            # Accept both the Flet-style names and the wire keys.
            art_board = artboard if art_board.nil?
            use_art_board_size = use_artboard_size if use_art_board_size.nil?

            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:alignment] = alignment unless alignment.nil?
            props[:animate_offset] = animate_offset unless animate_offset.nil?
            props[:animate_opacity] = animate_opacity unless animate_opacity.nil?
            props[:animate_position] = animate_position unless animate_position.nil?
            props[:animate_rotation] = animate_rotation unless animate_rotation.nil?
            props[:animate_scale] = animate_scale unless animate_scale.nil?
            props[:animations] = animations unless animations.nil?
            props[:art_board] = art_board unless art_board.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:clip_rect] = clip_rect unless clip_rect.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:enable_antialiasing] = enable_antialiasing unless enable_antialiasing.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fit] = fit unless fit.nil?
            props[:headers] = headers unless headers.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:placeholder] = placeholder unless placeholder.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:speed_multiplier] = speed_multiplier unless speed_multiplier.nil?
            props[:src] = src unless src.nil?
            props[:state_machines] = state_machines unless state_machines.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:use_art_board_size] = use_art_board_size unless use_art_board_size.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
