# frozen_string_literal: true

require_relative "test_helper"

# The HTML DSL helpers are included above Action View's own helpers, and a few
# share a name with an Action View form helper. A call with Action View's shape
# goes to the helper the DSL hides; every DSL call keeps the DSL markup.
# rails_form_helpers_test.rb checks the same against a real Rails app.
class RufletHtmlDslHiddenHelpersTest < Minitest::Test
  def self.options(hash) = "{#{hash.map { |key, value| "#{key}=#{value}" }.join(",")}}"

  # Action View's FormHelper signatures on Rails 8.
  module Rails8FormHelper
    def text_field(object_name, method, options = {})
      "rails text_field #{object_name}[#{method}] #{RufletHtmlDslHiddenHelpersTest.options(options)}"
    end

    def textarea(object_name, method, options = {})
      "rails textarea #{object_name}[#{method}] #{RufletHtmlDslHiddenHelpersTest.options(options)}"
    end

    def checkbox(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
      "rails checkbox #{object_name}[#{method}] #{RufletHtmlDslHiddenHelpersTest.options(options)} " \
        "#{checked_value}/#{unchecked_value}"
    end
  end

  # Rails 7 has no textarea or checkbox, only text_area and check_box.
  module Rails7FormHelper
    def text_field(object_name, method, options = {})
      "rails text_field #{object_name}[#{method}] #{RufletHtmlDslHiddenHelpersTest.options(options)}"
    end

    def text_area(object_name, method, options = {})
      "rails text_area #{object_name}[#{method}] #{RufletHtmlDslHiddenHelpersTest.options(options)}"
    end
  end

  class Rails8View
    include Rails8FormHelper
    include Ruflet::Rails::HtmlDsl::ViewHelpers
  end

  class Rails7View
    include Rails7FormHelper
    include Ruflet::Rails::HtmlDsl::ViewHelpers
  end

  class PlainView
    include Ruflet::Rails::HtmlDsl::ViewHelpers
  end

  # What ruflet_rails 0.0.23 renders for these DSL calls.
  DSL_CALLS = {
    -> { text_field(label: "Name", name: "name") } => '<text-field label="Name" name="name"></text-field>',
    -> { text_field("Ada") } => "<text-field>Ada</text-field>",
    -> { text_field { "inner" } } => "<text-field>inner</text-field>",
    -> { textarea("bio", "Hi", rows: 3) } => '<textarea rows="3" name="bio">Hi</textarea>',
    -> { textarea(:bio, "Hi") } => '<textarea name="bio">Hi</textarea>',
    -> { textarea(:bio) } => '<textarea name="bio"></textarea>',
    -> { textarea } => "<textarea></textarea>",
    -> { checkbox(name: "ok", label: "Agree", value: true) } => '<checkbox name="ok" label="Agree" value></checkbox>',
    -> { checkbox } => "<checkbox></checkbox>"
  }.freeze

  def test_form_builder_shaped_calls_reach_the_hidden_form_helper
    view = Rails8View.new

    assert_equal "rails text_field post[title] {}", view.text_field(:post, :title, {})
    assert_equal 'rails text_field post[title] {class=input}', view.text_field(:post, :title, class: "input")
    assert_equal "rails text_field post[title] {}", view.text_field("post", "title")
    assert_equal "rails textarea post[body] {}", view.textarea(:post, :body, {})
    assert_equal "rails checkbox post[published] {} yes/no", view.checkbox(:post, :published, {}, "yes", "no")
    assert_equal "rails checkbox post[published] {} 1/0", view.checkbox(:post, :published)
  end

  def test_textarea_with_a_symbol_attribute_reaches_the_hidden_form_helper
    view = Rails8View.new

    assert_equal "rails textarea post[body] {}", view.textarea(:post, :body)
    assert_equal "rails textarea post[body] {rows=4}", view.textarea("post", :body, rows: 4)
  end

  def test_dsl_calls_keep_their_markup_in_every_view
    [Rails8View.new, Rails7View.new, PlainView.new].each do |view|
      DSL_CALLS.each do |call, markup|
        assert_equal markup, view.instance_exec(&call), "#{view.class.name.split("::").last}: #{markup}"
      end
    end
  end

  def test_rails_7_views_hand_only_text_field_to_action_view
    view = Rails7View.new

    assert_equal "rails text_field post[title] {}", view.text_field(:post, :title)
    # Rails 7 has no textarea or checkbox, so those stay DSL helpers.
    assert_equal '<textarea name="post">body</textarea>', view.textarea(:post, :body)
    error = assert_raises(ArgumentError) { view.checkbox(:post, :published) }
    assert_equal "wrong number of arguments (given 2, expected 0)", error.message
  end

  def test_calls_the_dsl_cannot_take_still_raise_without_a_hidden_helper
    view = PlainView.new

    error = assert_raises(ArgumentError) { view.text_field(:post, :title) }
    assert_equal "wrong number of arguments (given 2, expected 0..1)", error.message
    error = assert_raises(ArgumentError) { view.textarea(:post, :body, {}) }
    assert_equal "wrong number of arguments (given 3, expected 0..2)", error.message
    assert_equal '<textarea name="post">body</textarea>', view.textarea(:post, :body)
  end

  def test_helpers_that_hide_nothing_are_not_wrapped
    helpers = Ruflet::Rails::HtmlDsl::ViewHelpers

    assert_equal [[:opt, :content], [:keyrest, :attrs], [:block, :block]], helpers.instance_method(:column).parameters
    assert_equal [[:opt, :content], [:keyrest, :attrs], [:block, :block]], helpers.instance_method(:alert_dialog).parameters
    assert_equal [[:opt, :name], [:keyrest, :attrs]], helpers.instance_method(:input).parameters
  end
end
