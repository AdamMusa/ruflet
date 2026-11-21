# frozen_string_literal: true

require_relative "test_helper"

# Page#fail_pending_invokes!: what the server calls when it closes a
# connection over a message it refused, so invokes waiting on that client
# end instead of waiting for a reply that cannot arrive.
class PagePendingInvokesTest < Minitest::Test
  INVOKE_ACTION = Ruflet::Protocol::ACTIONS[:invoke_control_method]
  ERROR = "a client message of at least 17000000 bytes exceeds the 16777216-byte limit"

  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "pending-invokes",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def test_fail_pending_invokes_ends_callbacks_and_waiters_with_the_error
    page = @page
    replies = []
    page.invoke(1, "pick_files", args: { "with_data" => true }, timeout: nil, on_result: ->(*reply) { replies << reply })
    page.invoke(1, "get_device_info", timeout: nil, on_result: ->(*reply) { replies << reply })
    waiter = Thread.new do
      page.invoke_sync(1, "get_application_cache_directory", timeout: 60)
      nil
    rescue RuntimeError => e
      e
    end
    waiter.report_on_exception = false
    sleep 0.005 until @sent.count { |action, _| action == INVOKE_ACTION } == 3

    ended = page.fail_pending_invokes!(ERROR)

    assert_equal 3, ended
    assert_equal [[nil, ERROR], [nil, ERROR]], replies
    raised = waiter.join(5)&.value
    assert_kind_of RuntimeError, raised, "invoke_sync kept waiting"
    assert_equal ERROR, raised.message
  end

  def test_a_failed_invoke_ignores_a_late_reply_and_is_not_failed_twice
    page = @page
    replies = []
    call_id = page.invoke(1, "pick_files", timeout: nil, on_result: ->(*reply) { replies << reply })

    page.fail_pending_invokes!(ERROR)

    refute page.handle_invoke_method_result("call_id" => call_id, "result" => ["late"], "error" => nil)
    assert_equal 0, page.fail_pending_invokes!(ERROR)
    assert_equal [[nil, ERROR]], replies
  end

  def test_a_raising_callback_does_not_stop_the_others
    page = @page
    replies = []
    page.invoke(1, "a", timeout: nil, on_result: ->(*) { raise "handler bug" })
    page.invoke(1, "b", timeout: nil, on_result: ->(*reply) { replies << reply })

    _out, err = capture_io { page.fail_pending_invokes!(ERROR) }

    assert_equal [[nil, ERROR]], replies
    assert_includes err, "invoke callback error: RuntimeError: handler bug"
  end
end
