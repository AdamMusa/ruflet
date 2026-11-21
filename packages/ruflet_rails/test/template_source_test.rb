# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"

# TemplateSource is the fetcher erb_to_native uses in production: it resolves a
# screen path to a controller action, runs it with no request behind it, and
# renders the action's ERB view. The other tests drive HtmlApp through a stub
# fetcher, so this boots a real Rails app with the Railtie loaded (see
# support/template_source_app.rb) and checks what the fetcher returns.
class RufletRailsTemplateSourceTest < Minitest::Test
  HARNESS = File.expand_path("support/template_source_app.rb", __dir__)
  LIB = File.expand_path("../lib", __dir__)

  def setup
    @result = self.class.result
    skip(@result["skip"]) if @result["skip"]
    flunk("template_source_app.rb: #{@result["error"]}") if @result["error"]
  end

  def test_a_screen_renders_its_action_with_app_helpers_railtie_helpers_and_partials
    assert_equal "/native", @result["home"]["url"]
    assert_equal '<column><text>home ADA</text><button on-click="/native/counter/increment">Up</button><text>nav</text> </column>',
                 @result["home"]["body"]
  end

  def test_an_action_without_a_template_re_runs_the_screens_own_action_before_rendering
    assert_equal "<column><text>count 0</text></column>", @result["counter"]["body"]
    assert_equal "<column><text>count 1</text></column>", @result["increment_1"]["body"],
                 "counter_increment re-renders counter.html.erb with the ivars #counter assigns"
    assert_equal "<column><text>count 2</text></column>", @result["increment_2"]["body"]
  end

  def test_redirect_to_renders_the_screen_it_names
    assert_equal({ "url" => "/native/counter", "body" => "<column><text>count 2</text></column>" }, @result["redirect"])
  end

  def test_a_redirect_loop_stops_with_an_error_screen
    body = @result["redirect_loop"]["body"]

    assert_includes body, "<h3>Screen failed</h3>"
    assert_includes body, "Too many redirects from /native/loop_forever"
  end

  def test_render_names_the_template_and_the_action_keeps_its_ivars
    assert_equal "<column><text>count 99</text></column>", @result["render_other"]["body"]
  end

  def test_trailing_path_segments_and_form_fields_arrive_as_params
    assert_equal "<text>feature camera</text>", @result["path_param"]["body"]
    assert_equal "<text>hi Grace</text>", @result["form_params"]["body"]
  end

  def test_a_path_without_a_controller_action_gets_the_missing_screen
    assert_includes @result["missing"]["body"], "<h3>No screen for /native/nowhere</h3>"
  end

  def test_an_edited_template_is_rendered_on_the_next_fetch
    assert_equal "<column><text>tally 2</text></column>", @result["edited"]["body"]
  end

  # One booted app for every test here: booting Rails is the slow part, and
  # the fetches run in order, as a session's taps do.
  def self.result
    @result ||= begin
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I", LIB, HARNESS)
      line = stdout.lines.reverse.find { |entry| entry.start_with?("RUFLET_TEMPLATE_SOURCE_RESULT ") }
      raise "template_source_app.rb printed no result (exit #{status.exitstatus})\n#{stdout}\n#{stderr}" unless line

      JSON.parse(line.delete_prefix("RUFLET_TEMPLATE_SOURCE_RESULT "))
    end
  end
end
