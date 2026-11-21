# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

# The Railtie includes the HTML DSL helpers into every view of the host app,
# web pages too. A few DSL helpers share a name with an Action View form
# helper: text_field, and on Rails 8 textarea and checkbox. form_with,
# form_for and fields_for builders call those helpers, so installing the gem
# made f.text_field, f.text_area, f.check_box (and the Rails 8 names) raise
# ArgumentError on ordinary pages.
#
# The harness (support/rails_form_helpers_app.rb) boots a real Rails app in
# its own process, once with ruflet_rails and once without it.
class RufletRailsFormHelpersTest < Minitest::Test
  HARNESS = File.expand_path("support/rails_form_helpers_app.rb", __dir__)
  LIB = File.expand_path("../lib", __dir__)
  # Each boot takes a moment; the tests share one run per environment.
  RUNS = {}
  RUNS_LOCK = Mutex.new

  # What ruflet_rails 0.0.23 renders for DSL calls; they must not change.
  DSL_MARKUP = {
    "dsl_text_field" => '<text-field label="Name" name="name"></text-field>',
    "dsl_text_field_content" => "<text-field>Ada</text-field>",
    "dsl_textarea" => '<textarea rows="3" name="bio">Hi</textarea>',
    "dsl_textarea_symbol_name" => '<textarea name="bio">Hi</textarea>',
    "dsl_textarea_name_only" => '<textarea name="bio"></textarea>',
    "dsl_checkbox" => '<checkbox name="ok" label="Agree"></checkbox>',
    "dsl_form" => '<form action="/signup" method="post"><text-field name="email"></text-field>' \
                  '<checkbox name="terms"></checkbox><textarea name="note"></textarea></form>'
  }.freeze

  def test_rails_form_helpers_render_the_same_markup_with_ruflet_rails_installed
    with_ruflet = run_app
    without_ruflet = run_app("WITHOUT_RUFLET" => "1")

    assert_equal true, with_ruflet["ruflet_rails"]
    assert_equal false, without_ruflet["ruflet_rails"]
    cases = without_ruflet["rails_cases"]
    assert_includes cases, "form_with_text_field"

    cases.each do |name|
      refute_match(/\ARAISED|\AHTTP/, without_ruflet["rendered"][name], "#{name} without ruflet_rails")
      assert_equal without_ruflet["rendered"][name], with_ruflet["rendered"][name],
                   "#{name}: a Rails form helper must render Action View's markup with ruflet_rails installed"
    end
    assert_includes with_ruflet["rendered"]["form_with_text_field"], '<input type="text" name="post[title]" id="post_title" />'
  end

  def test_rails_8_form_builder_names_render_action_view_markup
    result = run_app
    skip "Rails #{result["rails"]} has no FormBuilder#textarea" unless result["rails_cases"].include?("form_with_textarea")

    rendered = result["rendered"]
    assert_includes rendered["form_with_textarea"], '<textarea name="post[body]" id="post_body">'
    assert_includes rendered["form_with_checkbox"], '<input type="checkbox" value="1" name="post[published]" id="post_published" />'
    assert_equal %(<textarea rows="4" name="post[body]" id="post_body">\n</textarea>), rendered["direct_textarea_options"]
    assert_includes rendered["direct_checkbox"], 'name="post[published]"'
  end

  def test_dsl_helpers_keep_their_markup_in_a_rails_view
    rendered = run_app["rendered"]

    DSL_MARKUP.each do |name, markup|
      assert_equal markup, rendered[name], name
    end
  end

  private

  def run_app(env = {})
    result = RUNS_LOCK.synchronize { RUNS[env] ||= boot_app(env) }
    flunk(result["error"]) if result["error"]
    skip(result["skip"]) if result["skip"]
    result
  end

  def boot_app(env)
    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-I", LIB, HARNESS)
    line = stdout.lines.reverse.find { |entry| entry.start_with?("RUFLET_FORM_HELPERS_RESULT ") }
    return { "error" => "the form helpers app printed no result (exit #{status.exitstatus})\n#{stdout}\n#{stderr}" } unless line

    JSON.parse(line.delete_prefix("RUFLET_FORM_HELPERS_RESULT "))
  end
end
