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

        # `drop-shadow-*` is CSS's filter spelling of the same effect. Flutter
        # draws one BoxShadow either way, so both families share SHADOWS; only
        # the size names differ (drop-shadow has no 3xl-style top end).
        DROP_SHADOWS = {
          nil => "sm", "sm" => "sm", "md" => nil, "lg" => "md", "xl" => "lg", "2xl" => "xl", "none" => "none"
        }.freeze

        # Tailwind blend-mode name → Flutter BlendMode name, which is what a
        # container's `blend_mode` expects. CSS `normal` is Flutter's default
        # `srcOver`; `plus-lighter` is the closest thing to Flutter's `plus`.
        BLEND_MODES = {
          "normal" => "srcOver", "multiply" => "multiply", "screen" => "screen",
          "overlay" => "overlay", "darken" => "darken", "lighten" => "lighten",
          "color-dodge" => "colorDodge", "color-burn" => "colorBurn",
          "hard-light" => "hardLight", "soft-light" => "softLight",
          "difference" => "difference", "exclusion" => "exclusion",
          "hue" => "hue", "saturation" => "saturation", "color" => "color",
          "luminosity" => "luminosity", "plus-lighter" => "plus"
        }.freeze

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

        # Tailwind's named max-width scale, in logical pixels. Numeric forms
        # (`max-w-64`) go through the ordinary spacing scale instead. Relative
        # ceilings — full, none, fit, min, max — have no pixel value and are
        # dropped rather than guessed at.
        NAMED_WIDTHS = {
          "xs" => 320, "sm" => 384, "md" => 448, "lg" => 512, "xl" => 576,
          "2xl" => 672, "3xl" => 768, "4xl" => 896, "5xl" => 1024,
          "6xl" => 1152, "7xl" => 1280, "prose" => 672,
          "screen-sm" => 640, "screen-md" => 768, "screen-lg" => 1024,
          "screen-xl" => 1280, "screen-2xl" => 1536
        }.freeze

        # Tailwind cursor name → Flutter SystemMouseCursors name, which is what
        # a control's `mouse_cursor` prop expects.
        CURSORS = {
          "pointer" => "click", "not-allowed" => "forbidden", "wait" => "wait",
          "text" => "text", "default" => "basic", "auto" => "basic",
          "progress" => "progress", "move" => "move", "grab" => "grab",
          "grabbing" => "grabbing", "help" => "help", "none" => "none",
          "copy" => "copy", "cell" => "cell", "alias" => "alias",
          "no-drop" => "noDrop", "all-scroll" => "allScroll",
          "crosshair" => "precise", "zoom-in" => "zoomIn", "zoom-out" => "zoomOut",
          "col-resize" => "resizeColumn", "row-resize" => "resizeRow"
        }.freeze

        # `self-*` names a cross-axis position, but a control's `align` is a 2-D
        # Alignment and a class list cannot see which way its parent flexes.
        # Aligning on both axes is still right: on the main axis a flex child has
        # no slack to move within, so only the cross-axis component shows.
        SELF_ALIGN = {
          "start" => { "x" => -1, "y" => -1 },
          "center" => { "x" => 0, "y" => 0 },
          "end" => { "x" => 1, "y" => 1 }
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
          finalize_channel_opacity(props)
          finalize_border(props)
          finalize_shadow(props)
          finalize_gradient(props)
          finalize_animate(props)
          props
        end

        # Tailwind writes opacity onto the colour itself — bg-slate-900/50,
        # text-white/70 — and it is how most modern markup dims anything.
        # Flutter reads the alpha from the front of the hex, so a resolved
        # #rrggbb becomes #aarrggbb.
        def color_for(token)
          return nil if token.nil? || token.empty?

          base, alpha = token.split("/", 2)
          color = opaque_color_for(base)
          return color if alpha.nil? || color.nil?

          with_alpha(color, alpha)
        end

        def with_alpha(color, alpha)
          return color unless color.start_with?("#") && color.length == 7

          return color unless alpha.match?(/\A\d+\z/)

          percent = alpha.to_f
          return color unless percent <= 100

          "#%02x%s" % [(percent * 255 / 100).round.clamp(0, 255), color.delete_prefix("#")]
        end

        def opaque_color_for(token)
          return nil if token.nil? || token.empty?

          return arbitrary_color(Regexp.last_match(1)) if token =~ /\A\[(.+)\]\z/

          normalized = token.tr("-", "").downcase
          return NAMED_COLORS[normalized] if NAMED_COLORS.key?(normalized)
          return normalize_hex(token) if token.start_with?("#")

          family, shade = token.split("-", 2)
          shades = PALETTE[family]
          return nil unless shades

          index = SHADES.index(shade || "500")
          index && shades[index]
        end

        # Tailwind's arbitrary colour values — bg-[#0f172a], text-[rgb(15_23_42)],
        # border-[rgba(0,0,0,0.5)]. Tailwind spells spaces as underscores, so
        # both separators turn up in real markup. Notations Flutter cannot read
        # (hsl, oklch, var()) are dropped rather than guessed at.
        def arbitrary_color(body)
          body = body.tr("_", " ").strip
          return normalize_hex(body) if body.match?(/\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/)
          return nil unless body =~ /\Argba?\(([^)]*)\)\z/i

          parts = Regexp.last_match(1).split(%r{[\s,/]+}).reject(&:empty?)
          return nil if parts.length < 3

          hex = format("#%02x%02x%02x", *parts[0, 3].map { |part| channel_byte(part) })
          return hex unless parts[3]

          format("#%02x%s", alpha_byte(parts[3]), hex.delete_prefix("#"))
        end

        def channel_byte(part)
          value = part.end_with?("%") ? part.to_f * 255 / 100 : part.to_f
          value.round.clamp(0, 255)
        end

        def alpha_byte(part)
          value = part.end_with?("%") ? part.to_f * 255 / 100 : part.to_f * 255
          value.round.clamp(0, 255)
        end

        # Flutter reads #rrggbb and #aarrggbb. CSS's three-digit shorthand is
        # neither, so expand it; six- and eight-digit forms pass through.
        def normalize_hex(token)
          return token unless token =~ /\A#([0-9a-fA-F]{3})\z/

          "##{Regexp.last_match(1).chars.map { |digit| digit * 2 }.join}"
        end

        def apply_token(props, token)
          case token
          # --- spacing ---------------------------------------------------------
          when /\A(p|px|py|pt|pr|pb|pl)-(.+)\z/
            apply_edges(props, :padding, Regexp.last_match(1), Regexp.last_match(2))
          # Ahead of the margin rule, which matches mx-auto and then discards it
          # because "auto" is not a length.
          when "mx-auto", "m-auto" then props[:alignment] = "center"
          when /\A-?(m|mx|my|mt|mr|mb|ml)-(.+)\z/
            apply_edges(props, :margin, Regexp.last_match(1), Regexp.last_match(2), negative: token.start_with?("-"))
          # An axis-named gap is only "the" spacing when it runs along the flex's
          # own axis: space-y-4 is a Column's spacing but a Row's run_spacing.
          # The class list cannot see the axis, so both readings are recorded —
          # the row-shaped one under the plain keys (a Row is Tailwind's default
          # direction) and the axis under :spacing_x/:spacing_y, which the
          # transformer resolves once it knows which way the parent flexes.
          when /\A(?:gap-y|space-y)-(.+)\z/
            (value = length(Regexp.last_match(1))) && props.merge!(run_spacing: value, spacing_y: value)
          when /\A(?:gap-x|space-x)-(.+)\z/
            (value = length(Regexp.last_match(1))) && props.merge!(spacing: value, spacing_x: value)
          # A bare gap sets both axes, so it needs no resolving: on a wrapping
          # row it is the gap between items *and* between runs.
          when /\Agap-(.+)\z/
            (value = length(Regexp.last_match(1))) && props.merge!(spacing: value, run_spacing: value)
          # --- sizing ----------------------------------------------------------
          when "w-full", "h-full", "w-screen", "h-screen", "min-h-screen", "min-w-full",
               "flex-1", "grow", "expand", "flex-auto", "size-full"
            props[:expand] = true
          # The opposite instruction: hold your natural size, don't take the slack.
          when "shrink-0", "flex-none", "flex-initial", "grow-0", "basis-auto"
            props[:expand] = false
          when "basis-full" then props[:expand] = true
          # A fractional basis is proportional and `expand` is a flex factor, so
          # siblings written 1/3 and 2/3 become factors 1 and 2 — the same split.
          # Only the numerator carries; the denominator is the siblings' concern.
          when %r{\Abasis-(\d+)/\d+\z}
            props[:expand] = Regexp.last_match(1).to_i
          # Tailwind's flex-direction defaults to row, so a fixed basis is a width.
          when /\Abasis-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:width] = value
          # place-self / justify-self place a child inside its own grid area,
          # which is the same 2-D Alignment `self-*` resolves to above.
          when /\A(?:self|place-self|justify-self)-(start|center|end)\z/
            props[:align] = SELF_ALIGN[Regexp.last_match(1)]
          # `fit` is "shrink to your content", which is MainAxisSize.min —
          # Ruflet spells it `tight`. It is not a length, so it never becomes a
          # width or a height. Ahead of the size-/w-/h- rules, which match these
          # and then drop them.
          when "w-fit", "h-fit", "size-fit" then props[:tight] = true
          when /\Asize-(.+)\z/
            (value = length(Regexp.last_match(1))) && props.merge!(width: value, height: value)
          # Ahead of the w-/h- rules below, which match `max-w-md` and then drop
          # it (a named width is not a length), and which would file `max-w-64`
          # as a fixed width rather than as a ceiling.
          when /\A(min|max)-(w|h)-(.+)\z/
            apply_constraint(props, Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3))
          # A fractional width is a share of the row, which is what a flex
          # factor expresses: siblings written 1/3 and 2/3 become 1 and 2 and
          # split the same way. There is no percentage width to be literal
          # about, and the familiar class doing the familiar thing is the point.
          when %r{\Aw-(\d+)/\d+\z}
            props[:expand] = Regexp.last_match(1).to_i
          when /\Aw-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:width] = value
          when /\Ah-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:height] = value
          when "aspect-square" then props[:aspect_ratio] = 1.0
          when "aspect-video" then props[:aspect_ratio] = 16.0 / 9.0
          # Both spellings of a ratio: v3's aspect-[3/2] and v4's bare aspect-3/2.
          when %r{\Aaspect-\[?(\d+)/(\d+)\]?\z}
            props[:aspect_ratio] = Regexp.last_match(1).to_f / Regexp.last_match(2).to_f
          # --- flex direction --------------------------------------------------
          # `horizontal` is what the scrollable list-likes call their axis, and
          # it is also what tells `<div class="flex flex-row">` to build a Row
          # rather than the column a div gets by default. Column/Row take their
          # axis from the tag, so it is dropped there.
          when /\Aflex-(row|col)(-reverse)?\z/
            props[:horizontal] = Regexp.last_match(1) == "row"
            # Only the list-likes (ListView, GridView) can run backwards; a
            # Column has no `reverse`, so on a flex this is dropped.
            props[:reverse] = true if Regexp.last_match(2)
          # --- flex alignment --------------------------------------------------
          when /\Aitems-(.+)\z/
            (value = CROSS_AXIS[Regexp.last_match(1)]) && props[:cross_alignment] = value
          # align-content: how wrapped runs sit against each other.
          when /\Acontent-(.+)\z/
            (value = MAIN_AXIS[Regexp.last_match(1)]) && props[:run_alignment] = value
          when /\Ajustify-(.+)\z/
            (value = MAIN_AXIS[Regexp.last_match(1)]) && props[:main_alignment] = value
          # --- positioning (stack children) ------------------------------------
          when /\A-?(top|left|right|bottom)-(.+)\z/
            apply_position(props, Regexp.last_match(1), Regexp.last_match(2), negative: token.start_with?("-"))
          when /\A(-)?inset-x-(.+)\z/
            apply_inset(props, %w[left right], Regexp.last_match(2), negative: !Regexp.last_match(1).nil?)
          when /\A(-)?inset-y-(.+)\z/
            apply_inset(props, %w[top bottom], Regexp.last_match(2), negative: !Regexp.last_match(1).nil?)
          when /\A(-)?inset-(.+)\z/
            apply_inset(props, %w[top left right bottom], Regexp.last_match(2),
                        negative: !Regexp.last_match(1).nil?)
          # --- container content alignment -------------------------------------
          when "place-center", "grid-center"
            props[:alignment] = { "x" => 0, "y" => 0 }
          # place-items / place-content set both axes at once, which is exactly
          # what a Container's 2-D `alignment` is. Only the three positional
          # values convert; stretch and the space-* distributions have no
          # single point to align to.
          when /\A(?:place-items|place-content)-(start|center|end)\z/
            props[:alignment] = SELF_ALIGN[Regexp.last_match(1)]
          # --- typography ------------------------------------------------------
          when "text-center", "text-left", "text-right", "text-justify"
            props[:text_align] = token.split("-").last
          when "text-ellipsis" then props[:overflow] = "ellipsis"
          when "text-clip" then props[:overflow] = "clip"
          when /\Atext-(xs|sm|base|lg|[2-9]?xl)\z/
            props[:size] = TEXT_SIZES[Regexp.last_match(1)]
          # An arbitrary size — text-[13px], text-[1.125rem]. Deliberately
          # digit-anchored so it cannot swallow an arbitrary colour
          # (text-[#0f172a]), which the colour rule below owns.
          when /\Atext-(\[\d[^\]]*\])\z/
            (value = length(Regexp.last_match(1))) && props[:size] = value
          # Legacy channel opacity (text-opacity-70), applied to :color once the
          # whole class list has been read. Ahead of the text-colour rule, which
          # matches it and then drops it because "opacity-70" is not a colour.
          when /\Atext-opacity-(\d+)\z/
            props[:_color_opacity] = Regexp.last_match(1)
          when /\Atext-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:color] = value
          when /\Afont-(mono|serif|sans)\z/
            props[:font_family] = FONT_FAMILIES[Regexp.last_match(1)]
          # font-[Inter], font-['Fira Code'] — a named family, quotes and
          # underscore-for-space undone the way Tailwind writes them.
          when /\Afont-\[(.+)\]\z/
            props[:font_family] = Regexp.last_match(1).tr("_", " ").delete("'\"")
          when /\Afont-(.+)\z/
            (value = FONT_WEIGHTS[Regexp.last_match(1)]) && props[:weight] = value
          when "italic" then props[:italic] = true
          when "not-italic" then props[:italic] = false
          when /\Atracking-(tighter|tight|normal|wide|wider|widest)\z/
            props[:letter_spacing] = LETTER_SPACING[Regexp.last_match(1)]
          # tracking-[2px] / tracking-[0.5]. Flutter's letterSpacing is already
          # in logical pixels, which is what Tailwind's arbitrary value is too.
          when /\Atracking-\[(-?[\d.]+)(?:px)?\]\z/
            props[:letter_spacing] = Regexp.last_match(1).to_f
          when /\Aleading-(none|tight|snug|normal|relaxed|loose)\z/
            props[:line_height] = LINE_HEIGHT[Regexp.last_match(1)]
          # A unitless arbitrary leading is already a multiplier, which is
          # exactly what Flutter's `height` is.
          when /\Aleading-\[([\d.]+)\]\z/
            props[:line_height] = Regexp.last_match(1).to_f
          # leading-6 is a length (24px) and `height` is a multiple of the font
          # size, so the two only meet once the size is known. Held until
          # finalize, which divides by whatever :size the class list settled on.
          when /\Aleading-(.+)\z/
            (value = length(Regexp.last_match(1))) && props[:_leading_px] = value
          when "underline", "overline", "line-through"
            props[:decoration] = (props[:decoration] || 0) | DECORATIONS[token]
          when "no-underline" then props[:decoration] = 0
          when "uppercase", "lowercase", "capitalize" then props[:text_transform] = token
          when "normal-case" then props[:text_transform] = nil
          when "truncate" then props.merge!(max_lines: 1, overflow: "ellipsis")
          when "line-clamp-none" then props[:max_lines] = nil
          when /\Aline-clamp-(\d+)\z/
            props.merge!(max_lines: Regexp.last_match(1).to_i, overflow: "ellipsis")
          # Wrapping is the same prop from either vocabulary.
          when "break-words", "break-normal", "break-all" then props[:no_wrap] = false
          when "break-keep" then props[:no_wrap] = true
          when "whitespace-nowrap", "text-nowrap" then props[:no_wrap] = true
          when "whitespace-normal", "text-wrap" then props[:no_wrap] = false
          when "select-none" then props[:selectable] = false
          when "select-text", "select-all" then props[:selectable] = true
          # --- background / gradient ------------------------------------------
          # A container has one blend_mode, so the two CSS families — blending
          # the whole box against its backdrop (mix-blend) and blending the
          # background against its own content (bg-blend) — land on the same
          # prop. Ahead of the bg-colour rule, which would eat bg-blend-*.
          when /\A(?:mix-blend|bg-blend)-(.+)\z/
            (value = BLEND_MODES[Regexp.last_match(1)]) && props[:blend_mode] = value
          # Legacy channel opacity, applied to :bgcolor in finalize.
          when /\Abg-opacity-(\d+)\z/
            props[:_bgcolor_opacity] = Regexp.last_match(1)
          when /\Abg-gradient-to-(tr|tl|br|bl|[trbl])\z/
            props[:_grad_dir] = Regexp.last_match(1)
          when /\Afrom-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:_grad_from] = value
          when /\Avia-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:_grad_via] = value
          when /\Ato-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:_grad_to] = value
          when /\Abg-\[(#[0-9a-fA-F]+)\]\z/
            props[:bgcolor] = normalize_hex(Regexp.last_match(1))
          when /\Abg-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:bgcolor] = value
          # --- borders & corners ----------------------------------------------
          # Logical corners (rounded-s-lg, rounded-se-xl) resolved left-to-right.
          # Ahead of the physical rule, which matches "rounded-s-lg" as a whole
          # and then drops it because "s-lg" is neither a named nor a numeric
          # radius. `s`/`e` cannot simply join that rule's character class:
          # "rounded-sm" would then parse as a start-side corner plus junk.
          when /\Arounded-(ss|se|es|ee|s|e)(?:-(.+))?\z/
            apply_radius(props, "-#{Regexp.last_match(1)}", Regexp.last_match(2))
          when /\Arounded(-[trbl][trbl]?)?(?:-(.+))?\z/
            apply_radius(props, Regexp.last_match(1), Regexp.last_match(2))
          # Ahead of every other border rule: border-none is a removal, and the
          # colour rule below would otherwise swallow it and leave an earlier
          # `border` standing.
          when "border-none", "border-hidden" then props[:_border_off] = true
          when "border" then set_border(props, width: 1)
          when /\Aborder-(\d+)\z/ then set_border(props, width: Regexp.last_match(1).to_i)
          when /\Aborder-(t|r|b|l|x|y|s|e)(?:-(\d+))?\z/
            set_border(props, side: Regexp.last_match(1), width: (Regexp.last_match(2) || 1).to_i)
          when /\Aborder-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && set_border(props, color: value)
          # A ring is a stroke drawn round the box and an outline is a stroke
          # drawn just outside it; Flutter has one stroke per box, so both land
          # on :border. ring-inset and ring-offset-* have no Flutter spelling
          # and are dropped. Tailwind's bare `ring` is 3px wide, `outline` 1px.
          when "ring-inset", "ring-offset-0", "outline-none", "outline-hidden", "outline-0"
            nil
          when /\Aring-offset-/ then nil
          when "ring" then set_border(props, width: 3)
          when "outline" then set_border(props, width: 1)
          when /\A(?:ring|outline)-(\d+)\z/
            width = Regexp.last_match(1).to_i
            width.zero? ? props[:_border_off] = true : set_border(props, width: width)
          when /\A(?:ring|outline)-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && set_border(props, color: value)
          # --- effects ---------------------------------------------------------
          when /\Ashadow(?:-(sm|md|lg|xl|2xl|none))?\z/
            props[:shadow] = SHADOWS[Regexp.last_match(1)]
          when /\Adrop-shadow(?:-(sm|md|lg|xl|2xl|none))?\z/
            props[:shadow] = SHADOWS[DROP_SHADOWS[Regexp.last_match(1)]]
          # Tinted shadows (shadow-indigo-500/40). Behind the size rules so it
          # only sees names they rejected, and deferred to finalize so the pair
          # composes whichever order the two tokens are written in.
          when /\A(?:drop-)?shadow-(.+)\z/
            (value = color_for(Regexp.last_match(1))) && props[:_shadow_color] = value
          when /\Aopacity-(\d+)\z/
            props[:opacity] = Regexp.last_match(1).to_i / 100.0
          when /\Ablur(?:-(none|sm|md|lg|xl|2xl|3xl))?\z/
            props[:blur] = BLURS[Regexp.last_match(1)]
          when /\Ablur-\[(\d+)(?:px)?\]\z/ then props[:blur] = Regexp.last_match(1).to_i
          # A container's `blur` already *is* a backdrop filter — it blurs what
          # shows through the box, not the box itself — so the two families
          # share one prop and one scale.
          when /\Abackdrop-blur(?:-(none|sm|md|lg|xl|2xl|3xl))?\z/
            props[:blur] = BLURS[Regexp.last_match(1)]
          when /\Abackdrop-blur-\[(\d+)(?:px)?\]\z/ then props[:blur] = Regexp.last_match(1).to_i
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
          # `offset` translates by a fraction of the control's own size, so only
          # Tailwind's fractional translations convert exactly. The spacing-scale
          # forms (`-translate-y-2` = 8px) are pixels and are left alone.
          when %r{\A(-)?translate-(x|y)-(full|\d+/\d+)\z}
            apply_translate(props, Regexp.last_match(2), Regexp.last_match(3),
                            negative: !Regexp.last_match(1).nil?)
          # --- visibility / clipping / image fit -------------------------------
          when "hidden", "invisible" then props[:visible] = false
          when "visible" then props[:visible] = true
          when "overflow-hidden", "overflow-clip" then props[:clip_behavior] = "hardEdge"
          when "scroll", "overflow-auto", "overflow-y-auto", "overflow-scroll" then props[:scroll] = "auto"
          when /\Aobject-(contain|cover|fill|none|scale-down)\z/
            props[:fit] = OBJECT_FITS[Regexp.last_match(1)]
          when "wrap", "flex-wrap" then props[:wrap] = true
          when /\Acursor-(.+)\z/
            (value = CURSORS[Regexp.last_match(1)]) && props[:mouse_cursor] = value
          when "pointer-events-none" then props[:ignore_interactions] = true
          when "pointer-events-auto" then props[:ignore_interactions] = false
          # --- transitions / implicit animation --------------------------------
          # Tailwind names the properties that animate, and Ruflet has a
          # separate switch per property, so the narrow spellings drive the
          # narrow props instead of animating everything.
          when "transition-none" then props[:_anim_off] = true
          when "transition-opacity" then (props[:_anim_on] ||= []) << :animate_opacity
          when "transition-transform"
            (props[:_anim_on] ||= []).concat(%i[animate_offset animate_scale animate_rotation])
          when /\Atransition(?:-(all|colors|shadow))?\z/
            (props[:_anim_on] ||= []) << :animate
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
          off = props.delete(:_anim_off)
          return if off
          return unless on || duration || curve

          duration ||= 150
          value = curve ? { "duration" => duration, "curve" => curve } : duration
          keys = on.is_a?(Array) && !on.empty? ? on.uniq : [:animate]
          keys.each { |key| props[key] = value }
        end

        # bg-opacity-70 / text-opacity-50 — Tailwind's pre-v3 spelling, still
        # everywhere in real markup. The colour may be written either side of
        # the opacity, so the two are only combined once the list is read.
        def finalize_channel_opacity(props)
          { _bgcolor_opacity: :bgcolor, _color_opacity: :color, _border_opacity: :_border_color }
            .each do |source, target|
              alpha = props.delete(source)
              next unless alpha && props[target]

              props[target] = with_alpha(props[target], alpha)
            end
        end

        # shadow-indigo-500 recolours whatever shadow the size tokens chose,
        # and stands alone as a default-sized shadow in that colour.
        def finalize_shadow(props)
          color = props.delete(:_shadow_color)
          return unless color

          base = props[:shadow] || SHADOWS[nil]
          props[:shadow] = base.merge("color" => color)
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

        # min-w-64 / max-w-md / min-h-32. A ceiling is a different prop from a
        # fixed size, so these never touch :width/:height. Only a handful of
        # controls carry the constraint props (Text has max_width, Window has
        # all four), which is why the transformer filters them by schema.
        def apply_constraint(props, bound, axis, raw)
          value = axis == "w" ? NAMED_WIDTHS[raw] : nil
          value ||= length(raw)
          return unless value

          props[:"#{bound}_#{axis == 'w' ? 'width' : 'height'}"] = value
        end

        # translate-x-1/2, -translate-y-full. Both axes share one Offset, so a
        # second translate merges into the first rather than replacing it.
        def apply_translate(props, axis, raw, negative: false)
          fraction = translate_fraction(raw)
          return unless fraction

          fraction = -fraction if negative
          offset = props[:offset].is_a?(Hash) ? props[:offset] : { "x" => 0, "y" => 0 }
          props[:offset] = offset.merge(axis => fraction)
        end

        def translate_fraction(raw)
          return 1.0 if raw == "full"

          numerator, denominator = raw.split("/").map(&:to_f)
          return nil if denominator.nil? || denominator.zero?

          (numerator / denominator).round(4)
        end

        # inset-4 / -inset-x-2 — one length pinned to several edges at once.
        def apply_inset(props, edges, raw, negative: false)
          edges.each { |edge| apply_position(props, edge, raw, negative: negative) }
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

        # A CSS root font size, which is what `rem` is a multiple of. Tailwind's
        # own scale is built on 16 (`p-4` is 1rem is 16px), so the two agree.
        ROOT_FONT_SIZE = 16

        # Tailwind scale (`4` => 16), the one-pixel `px` step, and arbitrary
        # `[…]` values in px/rem/em/pt. Fractions (`w-1/2`) are percentages of a
        # parent Flutter never resolves at this level, so they stay unsupported.
        def length(raw)
          return nil if raw.nil?
          # `p-px`/`w-px`/`gap-px` — one physical pixel, not the spacing scale.
          return 1 if raw == "px"
          return arbitrary_length(Regexp.last_match(1), Regexp.last_match(2)) if raw =~ /\A\[(-?[\d.]+)(\D*)\]\z/
          return (raw.to_f * SPACING_UNIT).round if raw =~ /\A\d+(\.\d+)?\z/

          nil
        end

        # `w-[32rem]`, `p-[7px]`, `top-[2.5rem]`, `h-[40]`. Everything Flutter
        # measures is a logical pixel, so relative units resolve against the
        # root font size and anything else (%, vw, ch) is refused.
        def arbitrary_length(number, unit)
          case unit
          when "", "px" then number.to_f.round
          when "rem", "em" then (number.to_f * ROOT_FONT_SIZE).round
          when "pt" then (number.to_f * 4 / 3).round
          end
        end
      end
    end
  end
end
