# frozen_string_literal: true

require_relative "test_helper"
require "action_view"

# The native-shell helpers as a Rails app calls them: `<%= %>` in a template
# rendered by Action View. A label that comes from data (a user name, a record
# title) is text, escaped the way link_to and content_tag escape theirs, in the
# browser and in the native shell's WebView alike. Markup the template means
# (an html_safe label, a captured block) still renders as markup.
class RufletViewHelpersActionViewTest < Minitest::Test
  PAYLOAD = %(<img src=x onerror="alert(1)">)
  ESCAPED = "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;"

  LABEL_CALLS = {
    "ruflet_nav_item" => "ruflet_nav_item label, '/p', icon: 'person'",
    "ruflet_drawer_item" => "ruflet_drawer_item label, '/p', icon: 'person'",
    "ruflet_rail_item" => "ruflet_rail_item label, '/p', icon: 'person'",
    "ruflet_share_link" => "ruflet_share_link label, '/p'",
    "ruflet_copy_button" => "ruflet_copy_button label, text: 'x'",
    "ruflet_launch_link" => "ruflet_launch_link label, 'https://example.com'",
    "ruflet_haptic_button" => "ruflet_haptic_button label"
  }.freeze

  def view
    @view ||= Class.new(ActionView::Base.with_empty_template_cache) do
      include Ruflet::Rails::ViewHelpers
    end.new(ActionView::LookupContext.new([]), {}, nil)
  end

  def render(source, **locals)
    view.render(inline: source, locals: locals)
  end

  def test_a_label_from_data_renders_as_text_like_link_to
    assert_includes render("<%= link_to label, '/p' %>", label: PAYLOAD), ESCAPED

    LABEL_CALLS.each do |name, call|
      html = render("<%= #{call} %>", label: PAYLOAD)
      refute_includes html, "<img", "#{name} inserted its label as markup"
      assert_includes html, ">#{ESCAPED}</", name
    end
    assert_includes render("<%= ruflet_nav_item label, '/p', icon: 'person' %>", label: "Ada & <Bob>"),
                    ">Ada &amp; &lt;Bob&gt;</a>"
  end

  def test_a_label_from_data_inside_a_block_renders_as_text
    html = render(<<~ERB, label: PAYLOAD)
      <%= ruflet_bottom_nav do %>
        <%= ruflet_nav_item label, "/", icon: "house" %>
      <% end %>
    ERB

    assert_includes html, ">#{ESCAPED}</a>"
    refute_includes html, "<img"
  end

  # The native shell reads the label from the data-ruflet-icon JSON, which was
  # always escaped as an attribute; that copy of the label is unchanged.
  def test_the_native_label_in_the_icon_payload_is_unchanged
    html = render("<%= ruflet_nav_item label, '/p', icon: 'person' %>", label: "Ada & <Bob>")

    assert_includes html, "&quot;label&quot;:&quot;Ada &amp; &lt;Bob&gt;&quot;"
  end

  def test_an_html_safe_label_still_renders_as_markup
    LABEL_CALLS.each do |name, call|
      html = render("<%= #{call} %>", label: "<b>Hi</b>".html_safe)
      assert_includes html, "><b>Hi</b></", name
    end
  end

  def test_another_helpers_output_as_a_label_still_renders_as_markup
    html = render(%(<%= ruflet_copy_button content_tag(:strong, label), text: "x" %>), label: PAYLOAD)

    assert_includes html, "<button"
    assert_includes html, "><strong>#{ESCAPED}</strong></button>"
  end

  def test_block_content_still_renders_as_markup
    html = render(<<~ERB)
      <%= ruflet_bottom_nav do %>
        <%= ruflet_nav_item "<i>Raw</i>".html_safe, "/raw", icon: "x" %>
      <% end %>
      <%= ruflet_appbar "Inbox" do %><span class="t">Inbox</span><% end %>
    ERB

    assert_includes html, %(<nav data-ruflet-tabs="bottom-navigation" hidden="true">)
    assert_includes html, "><i>Raw</i></a>"
    assert_includes html, %(<span class="t">Inbox</span></header>)
  end

  def test_a_nil_or_false_label_still_renders_an_empty_tag
    LABEL_CALLS.each do |name, call|
      [nil, false].each do |label|
        html = render("<%= #{call} %>", label: label)
        assert_match %r{"></(a|button)>\z}, html, "#{name}(#{label.inspect})"
      end
    end
  end
end
