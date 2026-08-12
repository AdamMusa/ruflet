# frozen_string_literal: true

module Ruflet
  module Rails
    module HtmlDsl
      # Maps a Tailwind-flavored `class` attribute onto Ruflet control props.
      #
      # Returns a flat hash of prop-named keys (`:size`, `:padding`, `:bgcolor`,
      # `:border`, `:gradient`, `:rotate`, …). The transformer distributes these
      # onto the control itself (text props), onto a wrapping container (box
      # props), or onto any control whose schema accepts them (schema_style_props).
      module Styles
        SPACING_UNIT = 4

        TEXT_SIZES = {
          "xs" => 12, "sm" => 14, "base" => 16, "lg" => 18, "xl" => 20,
          "2xl" => 24, "3xl" => 30, "4xl" => 36, "5xl" => 48, "6xl" => 60,
          "7xl" => 72, "8xl" => 96, "9xl" => 128
        }.freeze

        FONT_WEIGHTS = {
          "thin" => "w100", "extralight" => "w200", "light" => "w300",
          "normal" => "normal", "medium" => "w500", "semibold" => "w600",
          "bold" => "bold", "extrabold" => "w800", "black" => "w900"
        }.freeze

        FONT_FAMILIES = { "mono" => "monospace", "serif" => "serif", "sans" => "sans-serif" }.freeze

        LETTER_SPACING = {
          "tighter" => -0.8, "tight" => -0.4, "normal" => 0.0,
          "wide" => 0.4, "wider" => 0.8, "widest" => 1.6
        }.freeze

        LINE_HEIGHT = {
          "none" => 1.0, "tight" => 1.25, "snug" => 1.375,
          "normal" => 1.5, "relaxed" => 1.625, "loose" => 2.0
        }.freeze

        # underline=1, overline=2, line-through=4 (bitmask; may combine).
        DECORATIONS = { "underline" => 1, "overline" => 2, "line-through" => 4 }.freeze

        CURVES = {
          "linear" => "linear", "in" => "easeIn", "out" => "easeOut", "in-out" => "easeInOut"
        }.freeze

        RADII = {
          nil => 4, "none" => 0, "sm" => 2, "md" => 6, "lg" => 8,
          "xl" => 12, "2xl" => 16, "3xl" => 24, "full" => 9999
        }.freeze

        MAIN_AXIS = {
          "start" => "start", "center" => "center", "end" => "end",
          "between" => "spaceBetween", "around" => "spaceAround", "evenly" => "spaceEvenly"
        }.freeze

        CROSS_AXIS = {
          "start" => "start", "center" => "center", "end" => "end",
          "stretch" => "stretch", "baseline" => "baseline"
        }.freeze

        SHADOWS = {
          "sm" => { "blur_radius" => 3, "color" => "#26000000", "offset" => { "x" => 0, "y" => 1 } },
          nil => { "blur_radius" => 6, "color" => "#26000000", "offset" => { "x" => 0, "y" => 2 } },
          "md" => { "blur_radius" => 10, "color" => "#26000000", "offset" => { "x" => 0, "y" => 4 } },
          "lg" => { "blur_radius" => 18, "color" => "#33000000", "offset" => { "x" => 0, "y" => 8 } },
          "xl" => { "blur_radius" => 28, "color" => "#33000000", "offset" => { "x" => 0, "y" => 12 } },
          "2xl" => { "blur_radius" => 40, "color" => "#40000000", "offset" => { "x" => 0, "y" => 20 } },
          "none" => nil
        }.freeze

        BLURS = { "none" => 0, "sm" => 2, nil => 4, "md" => 8, "lg" => 16, "xl" => 24, "2xl" => 40, "3xl" => 64 }.freeze

        # Fixed rotation angles (degrees) Tailwind ships, → radians.
        ROTATIONS = %w[0 1 2 3 6 12 45 90 180].freeze

        SCALES = {
          "0" => 0.0, "50" => 0.5, "75" => 0.75, "90" => 0.9, "95" => 0.95,
          "100" => 1.0, "105" => 1.05, "110" => 1.1, "125" => 1.25, "150" => 1.5
        }.freeze

        OBJECT_FITS = {
          "contain" => "contain", "cover" => "cover", "fill" => "fill",
          "none" => "none", "scale-down" => "scaleDown"
        }.freeze

        # Tailwind gradient direction → begin/end alignment ({x,y} in -1..1).
        GRADIENT_DIRS = {
          "r" => [{ "x" => -1, "y" => 0 }, { "x" => 1, "y" => 0 }],
          "l" => [{ "x" => 1, "y" => 0 }, { "x" => -1, "y" => 0 }],
          "t" => [{ "x" => 0, "y" => 1 }, { "x" => 0, "y" => -1 }],
          "b" => [{ "x" => 0, "y" => -1 }, { "x" => 0, "y" => 1 }],
          "tr" => [{ "x" => -1, "y" => 1 }, { "x" => 1, "y" => -1 }],
          "tl" => [{ "x" => 1, "y" => 1 }, { "x" => -1, "y" => -1 }],
          "br" => [{ "x" => -1, "y" => -1 }, { "x" => 1, "y" => 1 }],
          "bl" => [{ "x" => 1, "y" => -1 }, { "x" => -1, "y" => 1 }]
        }.freeze

        # Standard Tailwind palette (v3), most-used families.
        PALETTE = {
          "slate" => %w[#f8fafc #f1f5f9 #e2e8f0 #cbd5e1 #94a3b8 #64748b #475569 #334155 #1e293b #0f172a],
          "gray" => %w[#f9fafb #f3f4f6 #e5e7eb #d1d5db #9ca3af #6b7280 #4b5563 #374151 #1f2937 #111827],
          "zinc" => %w[#fafafa #f4f4f5 #e4e4e7 #d4d4d8 #a1a1aa #71717a #52525b #3f3f46 #27272a #18181b],
          "neutral" => %w[#fafafa #f5f5f5 #e5e5e5 #d4d4d4 #a3a3a3 #737373 #525252 #404040 #262626 #171717],
          "stone" => %w[#fafaf9 #f5f5f4 #e7e5e4 #d6d3d1 #a8a29e #78716c #57534e #44403c #292524 #1c1917],
          "red" => %w[#fef2f2 #fee2e2 #fecaca #fca5a5 #f87171 #ef4444 #dc2626 #b91c1c #991b1b #7f1d1d],
          "orange" => %w[#fff7ed #ffedd5 #fed7aa #fdba74 #fb923c #f97316 #ea580c #c2410c #9a3412 #7c2d12],
          "amber" => %w[#fffbeb #fef3c7 #fde68a #fcd34d #fbbf24 #f59e0b #d97706 #b45309 #92400e #78350f],
          "yellow" => %w[#fefce8 #fef9c3 #fef08a #fde047 #facc15 #eab308 #ca8a04 #a16207 #854d0e #713f12],
          "lime" => %w[#f7fee7 #ecfccb #d9f99d #bef264 #a3e635 #84cc16 #65a30d #4d7c0f #3f6212 #365314],
          "green" => %w[#f0fdf4 #dcfce7 #bbf7d0 #86efac #4ade80 #22c55e #16a34a #15803d #166534 #14532d],
          "emerald" => %w[#ecfdf5 #d1fae5 #a7f3d0 #6ee7b7 #34d399 #10b981 #059669 #047857 #065f46 #064e3b],
          "teal" => %w[#f0fdfa #ccfbf1 #99f6e4 #5eead4 #2dd4bf #14b8a6 #0d9488 #0f766e #115e59 #134e4a],
          "cyan" => %w[#ecfeff #cffafe #a5f3fc #67e8f9 #22d3ee #06b6d4 #0891b2 #0e7490 #155e75 #164e63],
          "sky" => %w[#f0f9ff #e0f2fe #bae6fd #7dd3fc #38bdf8 #0ea5e9 #0284c7 #0369a1 #075985 #0c4a6e],
          "blue" => %w[#eff6ff #dbeafe #bfdbfe #93c5fd #60a5fa #3b82f6 #2563eb #1d4ed8 #1e40af #1e3a8a],
          "indigo" => %w[#eef2ff #e0e7ff #c7d2fe #a5b4fc #818cf8 #6366f1 #4f46e5 #4338ca #3730a3 #312e81],
          "violet" => %w[#f5f3ff #ede9fe #ddd6fe #c4b5fd #a78bfa #8b5cf6 #7c3aed #6d28d9 #5b21b6 #4c1d95],
          "purple" => %w[#faf5ff #f3e8ff #e9d5ff #d8b4fe #c084fc #a855f7 #9333ea #7e22ce #6b21a8 #581c87],
          "fuchsia" => %w[#fdf4ff #fae8ff #f5d0fe #f0abfc #e879f9 #d946ef #c026d3 #a21caf #86198f #701a75],
          "pink" => %w[#fdf2f8 #fce7f3 #fbcfe8 #f9a8d4 #f472b6 #ec4899 #db2777 #be185d #9d174d #831843],
          "rose" => %w[#fff1f2 #ffe4e6 #fecdd3 #fda4af #fb7185 #f43f5e #e11d48 #be123c #9f1239 #881337]
        }.freeze
        SHADES = %w[50 100 200 300 400 500 600 700 800 900].freeze

        NAMED_COLORS = {
          "white" => "#ffffff", "black" => "#000000", "transparent" => "transparent",
          # Material theme tokens pass through as Ruflet theme color names.
          "primary" => "primary", "onprimary" => "onprimary",
          "primarycontainer" => "primarycontainer", "onprimarycontainer" => "onprimarycontainer",
          "secondary" => "secondary", "onsecondary" => "onsecondary",
          "secondarycontainer" => "secondarycontainer", "onsecondarycontainer" => "onsecondarycontainer",
          "tertiary" => "tertiary", "ontertiary" => "ontertiary",
          "error" => "error", "onerror" => "onerror",
          "surface" => "surface", "onsurface" => "onsurface",
          "surfacevariant" => "surfacevariant", "onsurfacevariant" => "onsurfacevariant",
          "inversesurface" => "inversesurface", "outline" => "outline"
        }.freeze

        module_function

        def parse(class_attr)
          props = {}
          class_attr.to_s.split(/\s+/).each { |token| apply_token(props, token) }
          finalize_border(props)
          finalize_gradient(props)
          finalize_animate(props)
          props
        end

        def color_for(token)
          return nil if token.nil? || token.empty?

          normalized = token.tr("-", "").downcase
          return NAMED_COLORS[normalized] if NAMED_COLORS.key?(normalized)
          return token if token.start_with?("#")

          family, shade = token.split("-", 2)
          shades = PALETTE[family]
          return nil unless shades

          index = SHADES.index(shade || "500")
          index && shades[index]
        end

        def apply_token(props, token)
          case token
          # --- spacing ---------------------------------------------------------
          when /\A(p|px|py|pt|pr|pb|pl)-(.+)\z/
            apply_edges(props, :padding, Regexp.last_match(1), Regexp.last_match(2))
          when /\A-?(m|mx|my|mt|mr|mb|ml)-(.+)\z/
            apply_edges(props, :margin, Regexp.last_match(1), Regexp.last_match(2), negative: token.start_with?("-"))
          when /\A(?:gap-y|space-y)-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:run_spacing] = value
          when /\A(?:gap-x|gap|space-x)-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:spacing] = value
          # --- sizing ----------------------------------------------------------
          when "w-full", "h-full", "w-screen", "h-screen", "min-h-screen", "min-w-full",
               "flex-1", "grow", "expand", "flex-auto", "size-full"
            props[:expand] = true
          when /\Asize-(.+)\z/
            (value = length(Regexp.last_match(1))) && props.merge!(width: value, height: value)
          when /\A(?:min-|max-)?w-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:width] = value
          when /\A(?:min-|max-)?h-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:height] = value
          when "aspect-square" then props[:aspect_ratio] = 1.0
          when "aspect-video" then props[:aspect_ratio] = 16.0 / 9.0
          when /\Aaspect-\[(\d+)\/(\d+)\]\z/
            props[:aspect_ratio] = Regexp.last_match(1).to_f / Regexp.last_match(2).to_f
          # --- flex alignment --------------------------------------------------
          when /\Aitems-(.+)\z/
            (value = CROSS_AXIS[Regexp.last_match(1)]) && props[:cross_alignment] = value
          when /\Ajustify-(.+)\z/
            (value = MAIN_AXIS[Regexp.last_match(1)]) && props[:main_alignment] = value
          # --- positioning (stack children) ------------------------------------
          when /\A-?(top|left|right|bottom)-(.+)\z/
            apply_position(props, Regexp.last_match(1), Regexp.last_match(2), negative: token.start_with?("-"))
          when /\Ainset-x-(.+)\z/
            %w[left right].each { |edge| apply_position(props, edge, Regexp.last_match(1)) }
          when /\Ainset-y-(.+)\z/
            %w[top bottom].each { |edge| apply_position(props, edge, Regexp.last_match(1)) }
          when /\Ainset-(.+)\z/
            %w[top left right bottom].each { |edge| apply_position(props, edge, Regexp.last_match(1)) }
          # --- container content alignment -------------------------------------
          when "place-items-center", "place-content-center", "place-center", "grid-center"
            props[:alignment] = { "x" => 0, "y" => 0 }
          # --- typography ------------------------------------------------------
          when "text-center", "text-left", "text-right", "text-justify"
            props[:text_align] = token.split("-").last
          when "text-ellipsis" then props[:overflow] = "ellipsis"
          when "text-clip" then props[:overflow] = "clip"
          when /\Atext-(xs|sm|base|lg|[2-9]?xl)\z/
            props[:size] = TEXT_SIZES[Regexp.last_match(1)]
          when /\Atext-\[(\d+)(?:px)?\]\z/
            props[:size] = Regexp.last_match(1).to_i
          when /\Atext-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:color] = value
          when /\Afont-(mono|serif|sans)\z/
            props[:font_family] = FONT_FAMILIES[Regexp.last_match(1)]
          when /\Afont-(.+)\z/
            (value = FONT_WEIGHTS[Regexp.last_match(1)]) && props[:weight] = value
          when "italic" then props[:italic] = true
          when "not-italic" then props[:italic] = false
          when /\Atracking-(tighter|tight|normal|wide|wider|widest)\z/
            props[:letter_spacing] = LETTER_SPACING[Regexp.last_match(1)]
          when /\Aleading-(none|tight|snug|normal|relaxed|loose)\z/
            props[:line_height] = LINE_HEIGHT[Regexp.last_match(1)]
          when "underline", "overline", "line-through"
            props[:decoration] = (props[:decoration] || 0) | DECORATIONS[token]
          when "no-underline" then props[:decoration] = 0
          when "uppercase", "lowercase", "capitalize" then props[:text_transform] = token
          when "normal-case" then props[:text_transform] = nil
          when "truncate" then props.merge!(max_lines: 1, overflow: "ellipsis")
          when "line-clamp-none" then props[:max_lines] = nil
          when /\Aline-clamp-(\d+)\z/
            props.merge!(max_lines: Regexp.last_match(1).to_i, overflow: "ellipsis")
          when "whitespace-nowrap", "text-nowrap" then props[:no_wrap] = true
          when "whitespace-normal", "text-wrap" then props[:no_wrap] = false
          when "select-none" then props[:selectable] = false
          when "select-text", "select-all" then props[:selectable] = true
          # --- background / gradient ------------------------------------------
          when /\Abg-gradient-to-(tr|tl|br|bl|[trbl])\z/
            props[:_grad_dir] = Regexp.last_match(1)
          when /\Afrom-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:_grad_from] = value
          when /\Avia-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:_grad_via] = value
          when /\Ato-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:_grad_to] = value
          when /\Abg-\[(#[0-9a-fA-F]+)\]\z/
            props[:bgcolor] = Regexp.last_match(1)
          when /\Abg-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:bgcolor] = value
          # --- borders & corners ----------------------------------------------
          when /\Arounded(-[trbl][trbl]?)?(?:-(.+))?\z/
            apply_radius(props, Regexp.last_match(1), Regexp.last_match(2))
          when "border" then set_border(props, width: 1)
          when /\Aborder-(\d+)\z/ then set_border(props, width: Regexp.last_match(1).to_i)
          when /\Aborder-(t|r|b|l|x|y)(?:-(\d+))?\z/
            set_border(props, side: Regexp.last_match(1), width: (Regexp.last_match(2) || 1).to_i)
          when /\Aborder-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && set_border(props, color: value)
          # --- effects ---------------------------------------------------------
          when /\Ashadow(?:-(sm|md|lg|xl|2xl|none))?\z/
            props[:shadow] = SHADOWS[Regexp.last_match(1)]
          when /\Aopacity-(\d+)\z/
            props[:opacity] = Regexp.last_match(1).to_i / 100.0
          when /\Ablur(?:-(none|sm|md|lg|xl|2xl|3xl))?\z/
            props[:blur] = BLURS[Regexp.last_match(1)]
          when /\Ablur-\[(\d+)(?:px)?\]\z/ then props[:blur] = Regexp.last_match(1).to_i
          # --- transforms ------------------------------------------------------
          when /\A(-?)rotate-(\d+)\z/
            if ROTATIONS.include?(Regexp.last_match(2))
              deg = Regexp.last_match(2).to_f
              deg = -deg if Regexp.last_match(1) == "-"
              props[:rotate] = (deg * Math::PI / 180).round(4)
            end
          when /\Arotate-\[(-?\d+)deg\]\z/
            props[:rotate] = (Regexp.last_match(1).to_f * Math::PI / 180).round(4)
          when /\Ascale-(\d+)\z/
            (value = SCALES[Regexp.last_match(1)]) && props[:scale] = value
          # --- visibility / clipping / image fit -------------------------------
          when "hidden", "invisible" then props[:visible] = false
          when "visible" then props[:visible] = true
          when "overflow-hidden", "overflow-clip" then props[:clip_behavior] = "hardEdge"
          when "scroll", "overflow-auto", "overflow-y-auto", "overflow-scroll" then props[:scroll] = "auto"
          when /\Aobject-(contain|cover|fill|none|scale-down)\z/
            props[:fit] = OBJECT_FITS[Regexp.last_match(1)]
          when "wrap", "flex-wrap" then props[:wrap] = true
          # --- transitions / implicit animation --------------------------------
          when /\Atransition(?:-(all|colors|opacity|transform|shadow))?\z/
            props[:_anim_on] = true
          when /\Aduration-(\d+)\z/
            props[:_anim_duration] = Regexp.last_match(1).to_i
          when /\Aease-(linear|in-out|in|out)\z/
            props[:_anim_curve] = CURVES[Regexp.last_match(1)]
          end
        end

        def finalize_animate(props)
          on = props.delete(:_anim_on)
          duration = props.delete(:_anim_duration)
          curve = props.delete(:_anim_curve)
          return unless on || duration || curve

          duration ||= 150
          props[:animate] = curve ? { "duration" => duration, "curve" => curve } : duration
        end

        # --- assembly helpers ---------------------------------------------------

        def apply_edges(props, key, prefix, raw, negative: false)
          value = length(raw)
          return unless value

          value = -value if negative
          edges = props[key].is_a?(Hash) ? props[key] : {}
          edges = uniform_to_edges(props[key]) if props[key].is_a?(Numeric)

          case prefix[-1]
          when "x" then edges = edges.merge("left" => value, "right" => value)
          when "y" then edges = edges.merge("top" => value, "bottom" => value)
          when "t" then edges = edges.merge("top" => value)
          when "r" then edges = edges.merge("right" => value)
          when "b" then edges = edges.merge("bottom" => value)
          when "l" then edges = edges.merge("left" => value)
          else
            props[key] = value
            return
          end
          props[key] = edges
        end

        def apply_position(props, edge, raw, negative: false)
          value = length(raw)
          return unless value

          props[edge.to_sym] = negative ? -value : value
        end

        # rounded / rounded-lg / rounded-t-lg / rounded-tl-xl
        def apply_radius(props, corner_group, size)
          radius = RADII.key?(size) ? RADII[size] : length(size)
          return if radius.nil?

          if corner_group.nil?
            # Uniform: replace unless per-corner values already exist.
            props[:border_radius] = props[:border_radius].is_a?(Hash) ? fill_corners(radius) : radius
            return
          end

          corners = radius_corners(corner_group.delete("-"))
          current = props[:border_radius].is_a?(Hash) ? props[:border_radius] : {}
          corners.each { |c| current[c] = radius }
          props[:border_radius] = current
        end

        def radius_corners(group)
          case group
          when "t" then %w[top_left top_right]
          when "b" then %w[bottom_left bottom_right]
          when "l" then %w[top_left bottom_left]
          when "r" then %w[top_right bottom_right]
          when "tl" then %w[top_left]
          when "tr" then %w[top_right]
          when "bl" then %w[bottom_left]
          when "br" then %w[bottom_right]
          else []
          end
        end

        def fill_corners(radius)
          { "top_left" => radius, "top_right" => radius, "bottom_left" => radius, "bottom_right" => radius }
        end

        def set_border(props, width: nil, color: nil, side: nil)
          props[:_border_width] = width if width
          props[:_border_color] = color if color
          sides = props[:_border_sides] ||= []
          sides.concat(border_sides(side)) if side
          props[:_border_seen] = true
        end

        def border_sides(side)
          case side
          when "x" then %w[left right]
          when "y" then %w[top bottom]
          when "t" then %w[top]
          when "r" then %w[right]
          when "b" then %w[bottom]
          when "l" then %w[left]
          else %w[top right bottom left]
          end
        end

        def finalize_border(props)
          return unless props.delete(:_border_seen)

          width = props.delete(:_border_width)
          color = props.delete(:_border_color)
          sides = props.delete(:_border_sides)
          sides = %w[top right bottom left] if sides.nil? || sides.empty?
          face = { "width" => width || 1 }
          face["color"] = color || "#e2e8f0"
          props[:border] = sides.uniq.each_with_object({}) { |side, out| out[side] = face }
        end

        def finalize_gradient(props)
          dir = props.delete(:_grad_dir)
          colors = [props.delete(:_grad_from), props.delete(:_grad_via), props.delete(:_grad_to)].compact
          return if colors.length < 2

          from_align, to_align = GRADIENT_DIRS[dir || "b"]
          props[:gradient] = { "_type" => "linear", "begin" => from_align, "end" => to_align, "colors" => colors }
        end

        def uniform_to_edges(value)
          { "left" => value, "top" => value, "right" => value, "bottom" => value }
        end

        # Tailwind scale (`4` => 16), fractions (`1/2` => 50% is unsupported, skipped),
        # and arbitrary `[Npx]` values.
        def length(raw)
          return nil if raw.nil?
          return Regexp.last_match(1).to_i if raw =~ /\A\[(\d+)(?:px)?\]\z/
          return (raw.to_f * SPACING_UNIT).round if raw =~ /\A\d+(\.\d+)?\z/

          nil
        end
      end
    end
  end
end
