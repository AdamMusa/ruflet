# frozen_string_literal: true

module Showcase
  module SectionsControls
    def build_responsive_row(page, status)
      cell = lambda do |label, bg, col|
        container(
          col: col,
          padding: 16,
          border_radius: 8,
          bgcolor: bg,
          content: text(value: label, style: { size: 14, weight: "w600", color: "#ffffff" })
        )
      end

      column(
        spacing: 16,
        children: [
          status,
          text(value: "Resize the window — columns reflow at each breakpoint.",
               style: { size: 13, color: color_subtle(page) }),

          # Each child spans the full 12 columns on phones, half on tablets,
          # and a third on desktops via a per-breakpoint `col` map.
          text(value: "Per-breakpoint col", style: { size: 14, weight: "w600" }),
          responsive_row(
            spacing: 10,
            run_spacing: 10,
            columns: 12,
            children: [
              cell.call("xs:12 / sm:6 / md:4", "#2563eb", { "xs" => 12, "sm" => 6, "md" => 4 }),
              cell.call("xs:12 / sm:6 / md:4", "#7c3aed", { "xs" => 12, "sm" => 6, "md" => 4 }),
              cell.call("xs:12 / sm:12 / md:4", "#db2777", { "xs" => 12, "sm" => 12, "md" => 4 })
            ]
          ),

          # A fixed split: a 4/8 sidebar + content layout.
          text(value: "Fixed 4 / 8 split", style: { size: 14, weight: "w600" }),
          responsive_row(
            spacing: 10,
            children: [
              container(col: 4, padding: 16, border_radius: 8, bgcolor: "#0f766e",
                        content: text(value: "Sidebar (col 4)", style: { color: "#ffffff" })),
              container(col: 8, padding: 16, border_radius: 8, bgcolor: "#334155",
                        content: text(value: "Content (col 8)", style: { color: "#ffffff" }))
            ]
          )
        ]
      )
    end
  end
end
