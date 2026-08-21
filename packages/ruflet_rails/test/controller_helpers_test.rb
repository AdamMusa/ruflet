# frozen_string_literal: true

require_relative "test_helper"

# render_native lets one action serve both clients: the native session gets the
# screen straight from the POST (one Rails cycle), a browser still gets the
# Post/Redirect/Get its reload button needs.
class RufletControllerHelpersTest < Minitest::Test
  class FakeRequest
    def initialize(headers) = @headers = headers
    attr_reader :headers
  end

  class FakeController
    include Ruflet::Rails::ControllerHelpers

    attr_reader :rendered

    def initialize(native:)
      @request = FakeRequest.new(native ? { "X-Ruflet-Native" => "1" } : {})
      @rendered = nil
    end

    attr_reader :request

    def render(template, **options)
      @rendered = [template, options]
    end
  end

  def test_native_requests_render_in_place
    controller = FakeController.new(native: true)
    redirected = false

    controller.render_native(:counter, else: -> { redirected = true })

    assert_equal [:counter, {}], controller.rendered
    refute redirected, "a native request must not take the redirect"
  end

  def test_browser_requests_take_the_fallback
    controller = FakeController.new(native: false)
    redirected = false

    controller.render_native(:counter, else: -> { redirected = true })

    assert_nil controller.rendered
    assert redirected, "a browser must still get Post/Redirect/Get"
  end

  def test_ruflet_native_request_reads_the_fetcher_marker
    assert FakeController.new(native: true).ruflet_native_request?
    refute FakeController.new(native: false).ruflet_native_request?
  end

  def test_browser_request_without_a_fallback_is_a_mistake
    controller = FakeController.new(native: false)

    assert_raises(ArgumentError) { controller.render_native(:counter) }
  end
end
