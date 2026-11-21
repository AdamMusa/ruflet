# frozen_string_literal: true

require_relative "test_helper"

# The page's internal overlay, services and dialogs containers keep fixed
# wire ids, so a client that reconnects with its old control tree merges a
# new Page's containers into the instances it already has (its View looks
# them up once). register_containers_patch hands them to a register reply
# that op patches follow (Ruflet::ConnectionProtocol, ruflet_rails).
class PageInternalContainersTest < Minitest::Test
  CONTAINER_KEYS = %w[_overlay _services _dialogs].freeze

  def new_page(route = "/")
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => route },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    [page, sent]
  end

  def container_ids(patch)
    CONTAINER_KEYS.to_h { |key| [key, patch.fetch(key).fetch("_i")] }
  end

  def page_ops(payload)
    payload.fetch("patch")[1..].map { |op| op[2] }
  end

  def test_container_ids_do_not_depend_on_the_content_registered_before_them
    short, = new_page("/")
    short.add(Ruflet.column(controls: [Ruflet.text("row 0")]))
    long, = new_page("/settings")
    long.add(Ruflet.column(controls: Array.new(6) { |i| Ruflet.text("row #{i}") }))

    expected = { "_overlay" => 3, "_services" => 4, "_dialogs" => 5 }
    assert_equal expected, container_ids(short.register_page_patch)
    assert_equal expected, container_ids(long.register_page_patch)
  end

  def test_fixed_container_ids_stay_clear_of_the_ids_the_allocator_hands_out
    page, = new_page
    rows = Array.new(3) { |i| Ruflet.text("row #{i}") }
    page.add(Ruflet.column(controls: rows))
    later = Ruflet.text("added later")
    page.add(later)

    ids = [*rows, later].map(&:wire_id)
    assert ids.all? { |id| id >= 100 }, "app controls start at 100: #{ids.inspect}"
    assert_equal ids.uniq, ids
    assert_equal [3, 4, 5], [Ruflet::Page::OVERLAY_WIRE_ID, Ruflet::Page::SERVICES_WIRE_ID, Ruflet::Page::DIALOGS_WIRE_ID]
  end

  def test_register_containers_patch_carries_only_the_containers_and_leaves_the_views_to_the_next_patch
    page, sent = new_page

    patch = page.register_containers_patch

    assert_equal CONTAINER_KEYS, patch.keys
    assert_equal({ "_overlay" => 3, "_services" => 4, "_dialogs" => 5 }, container_ids(patch))
    assert_empty sent

    page.add(Ruflet.text("body"))

    assert_equal 1, sent.length
    assert_equal 1, sent.first[1]["id"]
    ops = page_ops(sent.first[1])
    assert_includes ops, "views"
    assert_empty ops & CONTAINER_KEYS, "a replace op would replace the client's containers"
  end

  def test_a_bare_update_after_register_containers_patch_still_sends_the_page_shell
    page, sent = new_page
    page.register_containers_patch

    page.update

    assert_equal 1, sent.length
    ops = page_ops(sent.first[1])
    assert_includes ops, "views"
    assert_empty ops & CONTAINER_KEYS
  end

  def test_a_resumed_page_sends_its_open_dialog_in_the_containers_patch
    page, sent = new_page
    page.add(Ruflet.text("Still here"))
    page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("Still open")))
    sent.clear

    page.prepare_for_reconnect!
    patch = page.register_containers_patch
    page.update

    dialogs = patch.fetch("_dialogs")
    assert_equal 5, dialogs["_i"]
    assert_equal [["Still open", true]], dialogs["controls"].map { |d| [d["title"]["value"], d["open"]] }
    assert_equal 1, sent.length
    ops = page_ops(sent.first[1])
    assert_includes ops, "views"
    assert_empty ops & CONTAINER_KEYS
  end

  # Before the containers went in the register reply, the first view patch
  # carried them whole, so content an app block put in them without sending
  # anything still reached the client. It must still.
  def test_container_content_set_before_the_first_view_patch_still_reaches_the_client
    page, sent = new_page
    page.register_containers_patch
    page.overlay << Ruflet.text("overlay text")
    page.set_view_props(snack_bar: Ruflet.snack_bar(Ruflet.text("Saved")))

    page.add(Ruflet.text("body"))

    assert_equal [1, 3, 5], sent.map { |_action, payload| payload["id"] }
    assert_empty page_ops(sent[0][1]) & CONTAINER_KEYS
    assert_equal [["controls", ["overlay text"]]], sent[1][1]["patch"][1..].map { |op| [op[2], op[3].map { |c| c["value"] }] }
    assert_equal ["SnackBar"], sent[2][1]["patch"][1][3].map { |c| c["_c"] }
  end

  # The setters push their container as soon as it is mounted, so the
  # change that is still unsent is inside it: a prop of the snack bar,
  # dialog, sheet or overlay control, set after the setter. The first view
  # patch carried it on main, inside the whole container.
  def test_a_change_inside_a_container_before_the_first_view_patch_still_reaches_the_client
    cases = {
      "snack_bar=" => lambda do |page|
        sb = Ruflet.snack_bar(Ruflet.text("Welcome back"))
        page.snack_bar = sb
        sb.props["open"] = true
        page.add(Ruflet.text("body"))
      end,
      "dialog=" => lambda do |page|
        dialog = Ruflet.alert_dialog(title: Ruflet.text("Terms"))
        page.dialog = dialog
        dialog.props["open"] = true
        page.update
      end,
      "bottom_sheet=" => lambda do |page|
        sheet = Ruflet.bottom_sheet(Ruflet.text("Sheet"))
        page.bottom_sheet = sheet
        sheet.props["open"] = true
        page.add(Ruflet.text("body"))
      end
    }
    cases.each do |name, app|
      page, sent = new_page
      page.register_containers_patch
      app.call(page)

      assert_equal [5, 1, 5], sent.map { |_action, payload| payload["id"] }, name
      assert_nil sent[0][1]["patch"][1][3].first["open"], name
      assert_equal [true], sent[2][1]["patch"][1][3].map { |c| c["open"] }, name
    end
  end

  def test_an_overlay_control_changed_before_the_first_view_patch_is_sent_as_changed
    page, sent = new_page
    page.register_containers_patch
    text = Ruflet.text("before")
    page.overlay = [text]
    text.props["value"] = "after"

    page.add(Ruflet.text("body"))

    assert_equal [3, 1, 3], sent.map { |_action, payload| payload["id"] }
    assert_equal ["after"], sent[2][1]["patch"][1][3].map { |c| c["value"] }
  end

  # The flush is for the first view patch only: what the register reply's
  # containers predate. Later view patches send what they sent before, the
  # view patch alone (a container change that sent nothing is still not
  # sent there, as on main; see #145).
  def test_only_the_first_view_patch_flushes_unsent_container_changes
    page, sent = new_page
    page.register_containers_patch
    page.add(Ruflet.text("body"))
    sent.clear

    page.overlay << Ruflet.text("overlay text")
    page.add(Ruflet.text("more"))

    assert_equal [1], sent.map { |_action, payload| payload["id"] }
  end

  def test_containers_already_sent_are_not_sent_again_with_the_first_view_patch
    page, sent = new_page
    page.register_containers_patch
    page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("Shown")))

    page.add(Ruflet.text("body"))

    assert_equal [5, 1], sent.map { |_action, payload| payload["id"] }
  end

  # Without a register reply that carried the containers, show_dialog on a
  # fresh page still sends the page (and with it the containers) first.
  def test_show_dialog_on_a_page_whose_containers_are_not_mounted_sends_the_page_first
    page, sent = new_page

    page.show_dialog(Ruflet.alert_dialog(title: Ruflet.text("First")))

    assert_equal [1, 5], sent.map { |_action, payload| payload["id"] }
    assert_includes page_ops(sent.first[1]), "_dialogs"
  end
end
