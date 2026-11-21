# frozen_string_literal: true

# A model of what the Flutter client does with the patches a Page sends to
# its Dialogs layer, so Ruby tests can count the dialogs a user would see.
# It follows ruflet-engine (and the vendored engine in ruflet-template):
#
# * models/control.dart applyPatch: every control map in a whole-list
#   replace or in an add op becomes a NEW control instance, registered as the
#   newest instance for its id; remove and move ops keep the instances; a
#   patch addressed to a dialog's id goes to its newest instance.
# * the open/_open logic of alert_dialog.dart, the sheets and snack bars
#   (widgets/control_route.dart): when a frame rebuilds an instance that is
#   open and not yet presented (`_open` false), it presents it; when it
#   rebuilds one that is closed and presented, it pops it. The client reports
#   the pop later (`open: false`, then `dismiss`), and only then clears
#   `_open`. A dismiss by the user (barrier tap, swipe) pops it the same way.
# * an instance that leaves the list before a frame rebuilds it is never
#   rebuilt again: if it is on screen, it stays there ("stuck"), and nothing
#   Ruby sends can close it.
#
# Messages are applied in order; #frame! ends a client frame (the worst
# case: everything one Ruby handler sends lands in the same frame).
class DialogsClient
  Instance = Struct.new(:id, :title, :open, :presenting, :on_screen, keyword_init: true)

  attr_reader :list, :stuck

  def initialize
    @list = nil
    @container_id = nil
    @newest = {}
    @left_list = []
    @stuck = []
    @reports = []
  end

  def receive(payload)
    patch = payload["patch"]
    if payload["id"] == 1
      patch.drop(1).each do |op|
        next unless op[0].zero? && op[2] == "_dialogs" && op[3].is_a?(Hash)

        @container_id = op[3]["_i"]
        replace_list(op[3]["controls"])
      end
    elsif @container_id && payload["id"] == @container_id
      apply_container_ops(patch.drop(1))
    elsif (instance = @newest[payload["id"]])
      patch.drop(1).each do |op|
        instance.open = op[3] if op[0].zero? && op[2] == "open"
      end
    end
  end

  def frame!
    @list.each do |instance|
      if instance.open && !instance.presenting
        instance.presenting = true
        instance.on_screen = true
      elsif !instance.open && instance.on_screen
        pop(instance)
      end
    end
    @left_list.each { |instance| @stuck << instance if instance.on_screen }
    @left_list.clear
  end

  # The user dismisses the on-screen dialog titled `title` (barrier tap).
  def user_dismiss(title)
    instance = (@list || []).find { |entry| entry.title == title && entry.on_screen }
    raise "#{title} is not on screen" unless instance

    pop(instance)
  end

  def pending_reports?
    @reports.any?
  end

  # Delivers the oldest dismiss report to the page, as the engine's
  # _didDismiss does once the pop finished: `open: false`, then `dismiss`.
  def deliver_report(page)
    instance = @reports.shift
    instance.presenting = false
    instance.open = false
    page.apply_client_update(instance.id, { "open" => false })
    page.dispatch_event(target: instance.id, name: "dismiss", data: nil)
  end

  # How many copies of the dialog titled `title` are on screen.
  def visible(title)
    on_screen = (@list || []).select(&:on_screen) + @stuck
    on_screen.count { |instance| instance.title == title }
  end

  def ids
    (@list || []).map(&:id)
  end

  private

  def pop(instance)
    instance.on_screen = false
    @reports << instance
  end

  def apply_container_ops(ops)
    ops.each do |op|
      case op[0]
      when 0
        replace_list(op[3]) if op[1].zero? && op[2] == "controls"
      when 1
        raise "add at #{op[2]} outside a list of #{@list.size}" unless op[1] == 1 && op[2].between?(0, @list.size)

        @list.insert(op[2], instance_from(op[3]))
      when 2
        raise "remove at #{op[2]} outside a list of #{@list.size}" unless op[1] == 1 && op[2].between?(0, @list.size - 1)

        @left_list << @list.delete_at(op[2])
      when 3
        raise "move from #{op[2]} outside a list of #{@list.size}" unless op[2].between?(0, @list.size - 1)

        @list.insert(op[4], @list.delete_at(op[2]))
      else
        raise "unknown patch operation #{op.inspect}"
      end
    end
  end

  def replace_list(maps)
    @left_list.concat(@list) if @list
    @list = Array(maps).map { |map| instance_from(map) }
  end

  def instance_from(map)
    text = map["title"] || map["content"]
    title = text.is_a?(Hash) ? text["value"] : text
    instance = Instance.new(id: map["_i"], title: title, open: map["open"] == true, presenting: false, on_screen: false)
    @newest[instance.id] = instance
    instance
  end
end
