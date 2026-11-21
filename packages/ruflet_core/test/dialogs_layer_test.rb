# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/dialogs_client"

# The page's Dialogs layer (`_dialogs.controls`) changes by list operations:
# a dialog, sheet or snack bar that is already on the client is never sent
# again. Sending the whole list again made the client build a new control
# for every dialog in it, which presented a second copy of a dialog that was
# open and left the first copy on screen with nothing able to close it.
#
# DialogsClient (test/support) applies the patches the way the engine does
# and counts what a user would see. Each `step` is one handler: everything it
# sends reaches the client in the same frame, the worst case.
class RufletDialogsLayerTest < Minitest::Test
  def setup
    start_page
  end

  def test_a_snack_bar_over_an_open_dialog_leaves_one_copy_that_closes
    a = dialog("Dialog A")
    step { @page.show_dialog(a) }
    assert_equal 1, @client.visible("Dialog A")

    step { @page.show_snack_bar(snack("Saved")) }
    assert_equal 1, @client.visible("Dialog A")
    assert_equal 1, @client.visible("Saved")

    step { @page.close(a) }
    assert_equal 0, @client.visible("Dialog A")
    assert_empty @client.stuck
  end

  def test_a_second_overlay_is_sent_alone_as_an_add
    a = dialog("Dialog A")
    @page.show_dialog(a)
    assert_equal [[0, { "controls" => [1] }], [1, 1, 0, a.to_patch]], dialogs_patches.last

    s = snack("Saved")
    @page.show_snack_bar(s)
    assert_equal [[0, { "controls" => [1] }], [1, 1, 1, s.to_patch]], dialogs_patches.last
  end

  def test_a_dialog_over_a_modal_dialog_and_closing_both
    a = dialog("Dialog A", modal: true)
    b = dialog("Dialog B")
    step { @page.show_dialog(a) }
    step { @page.show_dialog(b) }
    assert_equal [1, 1], [@client.visible("Dialog A"), @client.visible("Dialog B")]

    step { @page.close(b) }
    step { @page.close(a) }
    settle
    assert_equal [0, 0], [@client.visible("Dialog A"), @client.visible("Dialog B")]
    assert_empty @client.stuck
  end

  def test_closing_a_dialog_and_showing_a_snack_bar_in_one_handler
    a = dialog("Dialog A")
    step { @page.show_dialog(a) }

    step do
      @page.close(a)
      @page.open(snack("Saved"))
    end

    assert_equal 0, @client.visible("Dialog A")
    assert_equal 1, @client.visible("Saved")
    assert_empty @client.stuck
  end

  def test_a_page_update_after_the_user_dismissed_the_top_dialog_keeps_the_other
    a = dialog("Dialog A")
    b = dialog("Dialog B")
    step { @page.show_dialog(a) }
    step { @page.show_dialog(b) }
    @client.user_dismiss("Dialog B")
    settle

    step { @page.update }

    assert_equal [1, 0], [@client.visible("Dialog A"), @client.visible("Dialog B")]
    # Only the dismissed dialog leaves the client's list.
    assert_equal [[0, { "controls" => [1] }], [2, 1, 1]], dialogs_patches.last
    assert_equal [a.wire_id], @client.ids
  end

  def test_a_dismissed_dialog_shows_again
    a = dialog("Dialog A")
    step { @page.show_dialog(a) }
    @client.user_dismiss("Dialog A")
    settle

    # Still in the client's list (nothing was sent since the dismiss).
    step { @page.show_dialog(a) }
    assert_equal 1, @client.visible("Dialog A")

    step { @page.close(a) }
    settle
    step { @page.update }
    assert_equal 0, @client.visible("Dialog A")

    step { @page.show_dialog(a) }
    assert_equal 1, @client.visible("Dialog A")
    assert_empty @client.stuck
  end

  def test_a_slot_dialog_closed_while_a_snack_bar_is_shown_in_one_handler
    a = dialog("Dialog A", open: true)
    step { @page.dialog = a }
    assert_equal 1, @client.visible("Dialog A")

    # close clears the dialog slot, so the dialog leaves the page's list in
    # the same handler that sends its open: false.
    step do
      @page.close(a)
      @page.show_snack_bar(snack("Saved"))
    end
    assert_equal 0, @client.visible("Dialog A")
    assert_empty @client.stuck

    # It leaves the client's list once the client reported it closed.
    settle
    step { @page.show_dialog(dialog("Dialog B")) }
    refute_includes @client.ids, a.wire_id
    assert_equal 1, @client.visible("Dialog B")
  end

  def test_a_flet_style_slot_dialog_reopens_on_the_same_control
    a = dialog("Dialog A")
    step { @page.dialog = a }
    step do
      a.props["open"] = true
      @page.update
    end
    assert_equal 1, @client.visible("Dialog A")

    @client.user_dismiss("Dialog A")
    settle
    step do
      a.props["open"] = true
      @page.update
    end
    assert_equal 1, @client.visible("Dialog A")

    # Not dropped as closed when the list changes next.
    step { @page.show_snack_bar(snack("Saved")) }
    assert_equal 1, @client.visible("Dialog A")
    assert_empty @client.stuck
  end

  def test_a_dialog_shown_again_while_it_closes_is_patched_not_resent
    a = dialog("Dialog A")
    step { @page.show_dialog(a) }
    step do
      @page.close(a)
      @page.show_dialog(a)
    end

    assert_equal 1, @client.visible("Dialog A")
    assert_equal({ "id" => a.wire_id, "patch" => [[0], [0, 0, "open", true]] }, @sent_log.last)
  end

  def test_changes_to_an_open_dialog_go_out_with_the_next_dialogs_update
    title = Ruflet.text("Dialog A")
    a = Ruflet.alert_dialog(title: title)
    step { @page.show_dialog(a) }

    title.props["value"] = "Saving"
    step { @page.show_snack_bar(snack("Saved")) }

    assert_includes @sent_log, { "id" => title.wire_id, "patch" => [[0], [0, 0, "value", "Saving"]] }
    assert_equal 1, @client.visible("Dialog A")
    # Published: a later bare update has nothing left to send for it.
    mark = @sent_log.size
    step { @page.update }
    assert_empty @sent_log.drop(mark)
  end

  def test_a_reconnected_client_gets_the_whole_list_then_list_operations
    a = dialog("Dialog A")
    step { @page.show_dialog(a) }

    @page.prepare_for_reconnect!
    @client = DialogsClient.new
    step { @page.update }
    assert_equal [a.wire_id], @client.ids
    assert_equal 1, @client.visible("Dialog A")

    b = dialog("Dialog B")
    step { @page.show_dialog(b) }
    assert_equal [a.wire_id, b.wire_id], @client.ids
    assert_equal [1, 1], [@client.visible("Dialog A"), @client.visible("Dialog B")]
  end

  def test_a_register_reply_is_the_new_baseline
    a = dialog("Dialog A")
    @page.show_dialog(a)
    @page.prepare_for_reconnect!
    reply = @page.register_page_patch

    assert_equal [a.to_patch], reply.fetch("_dialogs").fetch("controls")
    b = dialog("Dialog B")
    @page.show_dialog(b)
    assert_equal [[0, { "controls" => [1] }], [1, 1, 1, b.to_patch]], dialogs_patches.last
  end

  # Random handlers, user dismissals and late dismiss reports: no dialog is
  # ever on screen twice or stranded, the client's list always holds the
  # page's dialogs once each, and once everything is reported the client
  # shows exactly the dialogs the page has open.
  def test_random_sequences_never_duplicate_or_strand_an_overlay
    (1..12).each { |seed| random_walk(seed) }
  end

  private

  def start_page
    @sent = []
    @sent_log = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: lambda do |_action, payload|
        @sent << payload
        @sent_log << payload
      end
    )
    @client = DialogsClient.new
    step { @page.add(Ruflet.text("Body")) }
  end

  def step
    yield
    flush
  end

  def flush
    @sent.each { |payload| @client.receive(payload) }
    @sent.clear
    @client.frame!
  end

  # The client reports each finished pop, a frame apart.
  def settle
    while @client.pending_reports?
      @client.deliver_report(@page)
      flush
    end
  end

  def dialog(title, **props)
    Ruflet.alert_dialog(title: Ruflet.text(title), **props)
  end

  def snack(text)
    Ruflet.snack_bar(content: Ruflet.text(text))
  end

  def dialogs_patches
    id = @page.instance_variable_get(:@dialogs_container).wire_id
    @sent_log.select { |payload| payload["id"] == id }.map { |payload| payload["patch"] }
  end

  def random_walk(seed)
    start_page
    rng = Random.new(seed)
    pool = [
      dialog("D1"),
      dialog("D2", modal: true),
      snack("S1"),
      Ruflet.bottom_sheet(Ruflet.text("B1"))
    ]
    actions = [
      -> { @page.show_dialog(pool.sample(random: rng)) },
      -> { @page.close(pool.sample(random: rng)) },
      lambda do
        slot = @page.dialog
        @page.dialog = pool.sample(random: rng) if slot.nil? || slot.props["open"] != true
      end,
      lambda do
        slot = @page.dialog
        next unless slot

        slot.props["open"] = true
        @page.update
      end,
      -> { @page.update }
    ]

    250.times do |turn|
      context = "seed #{seed}, turn #{turn}"
      case rng.rand(6)
      when 0, 1
        step { actions.sample(random: rng).call }
      when 2
        # Two calls in one handler (close then show, show then show, ...).
        step { 2.times { actions.sample(random: rng).call } }
      when 3
        on_screen = pool.select { |control| @client.visible(title_of(control)) == 1 }
        @client.user_dismiss(title_of(on_screen.sample(random: rng))) unless on_screen.empty?
        flush
      else
        if @client.pending_reports?
          @client.deliver_report(@page)
          flush
        end
      end
      check_invariants(pool, context)
    end

    settle
    step { @page.update }
    settle
    wanted = Array(@page.instance_variable_get(:@dialogs_container).props["controls"])
    pool.each do |control|
      expected = wanted.any? { |entry| entry.equal?(control) } && control.props["open"] == true ? 1 : 0
      assert_equal expected, @client.visible(title_of(control)), "seed #{seed}: #{title_of(control)} after settling"
    end
  end

  def check_invariants(pool, context)
    assert_empty @client.stuck.map(&:title), "#{context}: stranded on screen"
    pool.each do |control|
      assert_operator @client.visible(title_of(control)), :<=, 1, "#{context}: #{title_of(control)} shown twice"
    end
    wanted = Array(@page.instance_variable_get(:@dialogs_container).props["controls"])
    wanted.each do |control|
      assert_equal 1, @client.ids.count(control.wire_id), "#{context}: #{title_of(control)} in the client's list"
    end
  end

  def title_of(control)
    text = control.props["title"] || control.props["content"]
    text.props["value"]
  end
end
