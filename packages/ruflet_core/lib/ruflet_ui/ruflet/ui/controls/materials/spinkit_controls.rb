# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Base for every flet_spinkit variant (https://flet.dev/docs/controls/spinkit/).
        # Each concrete spinner is a LayoutControl with its own wire name
        # ("SpinKitRotatingCircle", "SpinKitWave", ...). The Dart widget reads
        # color/size/duration for all of them plus the optional line_width /
        # border_width / item_count / wave_type used by a few variants, so those
        # are accepted on every spinner (the client ignores the ones a variant
        # doesn't use, matching the upstream implementation).
        class SpinKitControl < Ruflet::Control
          def initialize(id: nil, align: nil, animate_align: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, border_width: nil, bottom: nil, col: nil, color: nil, data: nil, disabled: nil, duration: nil, expand: nil, expand_loose: nil, height: nil, item_count: nil, key: nil, left: nil, line_width: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size: nil, tooltip: nil, top: nil, visible: nil, wave_type: nil, width: nil, on_animation_end: nil)
            raise ArgumentError, "spinkit size must be greater than or equal to 0" unless size.nil? || size >= 0

            props = {}
            props[:align] = align unless align.nil?
            props[:animate_align] = animate_align unless animate_align.nil?
            props[:animate_offset] = animate_offset unless animate_offset.nil?
            props[:animate_opacity] = animate_opacity unless animate_opacity.nil?
            props[:animate_position] = animate_position unless animate_position.nil?
            props[:animate_rotation] = animate_rotation unless animate_rotation.nil?
            props[:animate_scale] = animate_scale unless animate_scale.nil?
            props[:animate_size] = animate_size unless animate_size.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge] = badge unless badge.nil?
            props[:border_width] = border_width unless border_width.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:duration] = duration unless duration.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:item_count] = item_count unless item_count.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:line_width] = line_width unless line_width.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size] = size unless size.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:wave_type] = wave_type unless wave_type.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            super(type: self.class::TYPE, id: id, **props)
          end
        end

        # wire name ("_c") => ruflet type key. Mirrors flet_spinkit's 30 controls.
        SPINKIT_WIRE_TO_TYPE = {
          "SpinKitRotatingCircle" => "spinkit_rotating_circle",
          "SpinKitRotatingPlain" => "spinkit_rotating_plain",
          "SpinKitDoubleBounce" => "spinkit_double_bounce",
          "SpinKitWave" => "spinkit_wave",
          "SpinKitWanderingCubes" => "spinkit_wandering_cubes",
          "SpinKitFadingFour" => "spinkit_fading_four",
          "SpinKitFadingCube" => "spinkit_fading_cube",
          "SpinKitPulse" => "spinkit_pulse",
          "SpinKitChasingDots" => "spinkit_chasing_dots",
          "SpinKitThreeBounce" => "spinkit_three_bounce",
          "SpinKitCircle" => "spinkit_circle",
          "SpinKitCubeGrid" => "spinkit_cube_grid",
          "SpinKitFadingCircle" => "spinkit_fading_circle",
          "SpinKitFoldingCube" => "spinkit_folding_cube",
          "SpinKitPumpingHeart" => "spinkit_pumping_heart",
          "SpinKitHourGlass" => "spinkit_hour_glass",
          "SpinKitPouringHourGlass" => "spinkit_pouring_hour_glass",
          "SpinKitPouringHourGlassRefined" => "spinkit_pouring_hour_glass_refined",
          "SpinKitFadingGrid" => "spinkit_fading_grid",
          "SpinKitRing" => "spinkit_ring",
          "SpinKitRipple" => "spinkit_ripple",
          "SpinKitDualRing" => "spinkit_dual_ring",
          "SpinKitSpinningCircle" => "spinkit_spinning_circle",
          "SpinKitSpinningLines" => "spinkit_spinning_lines",
          "SpinKitSquareCircle" => "spinkit_square_circle",
          "SpinKitThreeInOut" => "spinkit_three_in_out",
          "SpinKitDancingSquare" => "spinkit_dancing_square",
          "SpinKitPianoWave" => "spinkit_piano_wave",
          "SpinKitPulsingGrid" => "spinkit_pulsing_grid",
          "SpinKitWaveSpinner" => "spinkit_wave_spinner"
        }.freeze

        # type key => control class, e.g. "spinkit_wave" => SpinKitWaveControl.
        SPINKIT_CONTROLS = {}

        SPINKIT_WIRE_TO_TYPE.each do |wire, type_key|
          klass = Class.new(SpinKitControl)
          klass.const_set(:TYPE, type_key)
          klass.const_set(:WIRE, wire)
          const_set("#{wire}Control", klass)
          SPINKIT_CONTROLS[type_key] = klass
        end

        SPINKIT_CONTROLS.freeze
      end
    end
  end
end
