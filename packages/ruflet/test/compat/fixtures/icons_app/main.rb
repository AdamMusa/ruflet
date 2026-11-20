# frozen_string_literal: true

# Icon fixture for the compatibility goldens: one control per way an app names
# an icon, so a change to the codepoint any of them sends is a golden diff.
# ADD, HOME and SEARCH are in both the Material and the Cupertino set, with
# different codepoints; HOUSE_FILL is Cupertino-only; CLASS is the one name
# whose constant differs from its map key (CLASS_).
require "ruflet"

Ruflet.run do |page|
  page.title = "Icons"
  page.add(
    column(
      controls: [
        icon(icon: "add"),
        icon(icon: :home),
        icon(icon: "arrow back"),
        icon(icon: Ruflet::MaterialIcons::ADD),
        icon(icon: Ruflet::MaterialIcons[:home]),
        icon(icon: Ruflet::CupertinoIcons::ADD),
        icon(icon: Ruflet::CupertinoIcons::HOME),
        icon(icon: Ruflet::CupertinoIcons::HOUSE_FILL),
        icon(icon: Ruflet::CupertinoIcons[:search]),
        icon(icon: Ruflet::Icons::HOME),
        icon(icon: Ruflet::Icons::HOUSE_FILL),
        icon(icon: Ruflet::Icons.material[:settings]),
        icon(icon: Ruflet::Icons.cupertino[:add]),
        icon(icon: Ruflet::Icons[:search]),
        icon(icon: Ruflet::IconData.new(Ruflet::CupertinoIcons::ADD)),
        icon(icon: Ruflet::MaterialIcons::CLASS),
        icon(icon: Ruflet::Icons[:class]),
        icon_button(icon: Ruflet::CupertinoIcons::ADD),
        cupertino_button("Add", icon: Ruflet::CupertinoIcons::ADD),
        floating_action_button(icon: Ruflet::CupertinoIcons::HOME),
        text_field(prefix_icon: Ruflet::CupertinoIcons::SEARCH)
      ]
    )
  )
end
