# frozen_string_literal: true

require_relative "test_helper"

# Adding a service must NOT re-serialize already-mounted services as full
# objects. On the client, Control.fromMap replaces a service's Control instance
# while ServiceRegistry only binds ids it hasn't seen, so a re-sent service
# keeps its old binding while controlsIndex points at a fresh, listener-less
# instance — and its next invoke hangs. That was the "after Copy, Share stops
# working" bug. Updates must add/remove individual services instead.
class PageServiceIncrementalUpdateTest < Minitest::Test
  def test_adding_a_service_does_not_resend_existing_services_as_full_objects
    sent = []
    page = build_page(sent)
    page.add(Ruflet.text(value: "x")) # mount the (empty) service registry

    share = page.share(key: "share")
    refute_nil share.wire_id, "share service is mounted on the client"

    sent.clear
    page.clipboard(key: "clipboard") # add a second service

    services_patch = sent.reverse.map(&:last).find do |payload|
      payload["id"] == page.instance_variable_get(:@services_container).wire_id
    end
    refute_nil services_patch, "adding a service patches the service registry in place"

    ops = services_patch["patch"][1..]
    # The new clipboard service is appended (op type 1 == add).
    assert ops.any? { |op| op[0] == 1 && op.last.is_a?(Hash) && op.last["_c"] == "Clipboard" },
           "the new clipboard service is added incrementally"
    # The already-mounted share service is never re-serialized as a full object.
    refute serialized_control?(ops, "Share"),
           "an existing service must not be re-sent as a full object (that detaches its invoke listener)"
    refute serialized_control_id?(ops, share.wire_id),
           "the existing share Control instance must not be replaced on the client"
  end

  def test_removing_a_service_emits_a_remove_op_and_keeps_the_other
    sent = []
    page = build_page(sent)
    page.add(Ruflet.text(value: "x"))

    share = page.share(key: "share")
    clipboard = page.clipboard(key: "clipboard")

    sent.clear
    page.remove_service(clipboard)

    services_patch = sent.reverse.map(&:last).find do |payload|
      payload["id"] == page.instance_variable_get(:@services_container).wire_id
    end
    refute_nil services_patch
    ops = services_patch["patch"][1..]

    assert ops.any? { |op| op[0] == 2 }, "removing a service emits a remove op"
    refute serialized_control_id?(ops, share.wire_id),
           "the surviving share service is not re-serialized"
  end

  private

  def serialized_control?(ops, wire_type)
    ops.any? { |op| deep_has_control_type?(op, wire_type) }
  end

  def serialized_control_id?(ops, wire_id)
    ops.any? { |op| deep_has_control_id?(op, wire_id) }
  end

  def deep_has_control_type?(node, wire_type)
    case node
    when Hash
      return true if node["_c"] == wire_type

      node.values.any? { |v| deep_has_control_type?(v, wire_type) }
    when Array
      node.any? { |v| deep_has_control_type?(v, wire_type) }
    else
      false
    end
  end

  def deep_has_control_id?(node, wire_id)
    case node
    when Hash
      return true if node["_i"] == wire_id

      node.values.any? { |v| deep_has_control_id?(v, wire_id) }
    when Array
      node.any? { |v| deep_has_control_id?(v, wire_id) }
    else
      false
    end
  end

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end
