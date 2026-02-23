require "ruby_native"

class Suite
  attr_reader :name, :color

  def initialize(name, color)
    @name = name
    @color = color
  end
end

class Rank
  attr_reader :name, :value

  def initialize(name, value)
    @name = name
    @value = value
  end
end

class Slot
  attr_reader :type, :left, :top, :width, :height, :pile

  def initialize(type:, left:, top:, width:, height:, border: true)
    @type = type
    @left = left
    @top = top
    @width = width
    @height = height
    @border = border
    @pile = []
  end

  def key
    "#{type}-#{left}-#{top}"
  end

  def add_card(card)
    @pile << card
  end

  def remove_card(card)
    @pile.delete(card)
  end

  def top_card
    @pile.last
  end

  def top_three_cards
    n = @pile.length
    @pile[[0, n - 3].max...n] || []
  end

  def upper_card_top(card_offset)
    return top + card_offset * (@pile.length - 1) if type == :tableau && @pile.length > 1

    top
  end

  def view(page, on_click: nil)
    props = {
      left: left,
      top: top,
      width: width,
      height: height,
      border_radius: 12,
      bgcolor: "#cfccd2"
    }
    props[:on_click] = on_click if on_click

    if @border
      props[:border] = { width: 1, color: "#b9b6be" }
    end

    page.container(**props, content: page.text(value: "", size: 1))
  end
end

class Card
  RANK_CODE = {
    "Ace" => "A", "Jack" => "J", "Queen" => "Q", "King" => "K"
  }.freeze
  SUIT_CODE = {
    "spades" => "S", "hearts" => "H", "diamonds" => "D", "clubs" => "C"
  }.freeze

  attr_reader :suite, :rank, :control
  attr_accessor :left, :top, :slot, :face_up, :visible

  def initialize(solitaire:, suite:, rank:, width:, height:)
    @solitaire = solitaire
    @suite = suite
    @rank = rank
    @width = width
    @height = height
    @slot = nil
    @face_up = false
    @visible = true
    @left = 0
    @top = 0
    @drag_origin_top = 0
    @drag_origin_left = 0
    @control = nil
  end

  def code
    rank_code = RANK_CODE.fetch(rank.name, rank.name)
    rank_code = "0" if rank.name == "10"
    "#{rank_code}#{SUIT_CODE.fetch(suite.name)}"
  end

  def image_url
    return "https://deckofcardsapi.com/static/img/back.png" unless face_up

    "https://deckofcardsapi.com/static/img/#{code}.png"
  end

  def can_be_moved?
    return false unless visible

    if slot.type == :waste
      slot.top_card == self
    else
      face_up
    end
  end

  def get_cards_to_move
    return [self] unless slot && slot.type == :tableau

    idx = slot.pile.index(self)
    idx ? slot.pile[idx..] : [self]
  end

  def remember_origin
    @drag_origin_top = top
    @drag_origin_left = left
  end

  def bounce_back!
    cards = get_cards_to_move
    cards.each_with_index do |card, i|
      card.top = @drag_origin_top + (slot.type == :tableau ? i * @solitaire.card_offset : 0)
      card.left = @drag_origin_left
      @solitaire.patch_card(card)
    end
  end

  def turn_face_up!
    @face_up = true
    @solitaire.patch_card(self)
  end

  def turn_face_down!
    @face_up = false
    @visible = true
    @solitaire.patch_card(self)
  end

  def place(slot)
    old_slot = @slot
    old_slot.remove_card(self) if old_slot

    @slot = slot
    @left = slot.left
    @top = slot.top + (slot.type == :tableau ? @solitaire.card_offset * slot.pile.length : 3)

    slot.add_card(self)
    # Match Python version: each placement brings this card to top render order.
    @solitaire.move_on_top([self])
    @solitaire.patch_card(self)
  end

  def view(page)
    return nil unless visible

    @control ||= page.gesture_detector(
      left: left,
      top: top,
      visible: visible,
      on_pan_start: ->(_e) { @solitaire.start_drag(self) },
      on_pan_update: ->(e) { @solitaire.drag(self, e) },
      on_pan_end: ->(_e) { @solitaire.drop(self) },
      on_tap: ->(_e) { @solitaire.card_tap(self) },
      on_double_tap: ->(_e) { @solitaire.card_double_tap(self) },
      content: page.image(image_url, width: @width, height: @height, fit: "fill")
    )
  end
end

class Solitaire
  TABLE_BG = "#d9d7db".freeze
  TITLE_COLOR = "#232329".freeze
  STATUS_COLOR = "#4d4c57".freeze

  attr_reader :card_offset

  def initialize(page)
    @page = page
    @status_text = "Drag cards"

    @card_offset = 26
    @deck_passes_allowed = 3
    @deck_passes_remaining = @deck_passes_allowed
    @waste_size = 3

    @slots = []
    @cards = []
    @status_control = nil

    setup_layout
    create_slots
    create_deck
    deal_cards
    render_scene
  end

  def start_drag(card)
    return unless card.can_be_moved?

    @drag_cards = card.get_cards_to_move
    move_on_top(@drag_cards)
    card.remember_origin
    @status_text = "Dragging #{card.rank.name} #{card.suite.name}"
    @page.update(@status_control, value: @status_text) if @status_control
  end

  def drag(card, event)
    return unless card.can_be_moved?
    return if @drag_cards.nil? || @drag_cards.empty?

    dx = dig_number(event.data, "ld", "x")
    dy = dig_number(event.data, "ld", "y")
    return if dx.zero? && dy.zero?

    base_left = card.left + dx
    base_top = card.top + dy

    @drag_cards.each_with_index do |c, i|
      c.left = base_left
      c.top = base_top + (c.slot.type == :tableau ? i * @card_offset : 0)
      patch_card(c)
    end
  end

  def drop(card)
    return unless card.can_be_moved?
    return if @drag_cards.nil? || @drag_cards.empty?

    target = nil
    candidate_slots.each do |slot|
      next unless (card.top - slot.upper_card_top(@card_offset)).abs < 40
      next unless (card.left - slot.left).abs < 40

      if slot.type == :tableau
        if check_tableau_rules(card, slot.top_card)
          target = slot
          break
        end
      elsif slot.type == :foundation
        if @drag_cards.length == 1 && check_foundation_rules(card, slot.top_card)
          target = slot
          break
        end
      end
    end

    if target
      old_slot = card.slot
      @drag_cards.each { |c| c.place(target) }
      reveal_old_tableau_top(old_slot)
      display_waste if old_slot&.type == :waste
      @status_text = "Moved #{card.rank.name} #{card.suite.name}"
    else
      card.bounce_back!
      @status_text = "Invalid move"
    end

    @drag_cards = []
    @page.update(@status_control, value: @status_text) if @status_control
  end

  def card_tap(card)
    if card.slot.type == :stock
      draw_from_stock
    elsif card.slot.type == :tableau
      top = card.slot.top_card
      top.turn_face_up! if top == card && !card.face_up
    end
  end

  def card_double_tap(card)
    return unless [:waste, :tableau].include?(card.slot.type)
    return unless card.face_up

    move_on_top([card])
    old_slot = card.slot
    @foundation.each do |slot|
      next unless check_foundation_rules(card, slot.top_card)

      card.place(slot)
      reveal_old_tableau_top(old_slot)
      display_waste if old_slot.type == :waste
      @status_text = "Moved to foundation"
      @page.update(@status_control, value: @status_text) if @status_control
      return
    end
  end

  def patch_card(card)
    return unless card.control

    @page.update(card.control, left: card.left, top: card.top, visible: card.visible)
    @page.update(card.control.children.first, src: card.image_url) rescue nil
  end

  def move_on_top(cards)
    cards.each { |c| @cards.delete(c) }
    @cards.concat(cards)
  end

  private

  def setup_layout
    screen_width = dig_number(@page.client_details, "width")
    screen_height = dig_number(@page.client_details, "height")
    screen_width = 1000 if screen_width <= 0
    screen_height = 700 if screen_height <= 0

    board_padding = 12
    @slot_gap = 24
    @slot_w = [[((screen_width - (2 * board_padding) - (6 * @slot_gap)) / 7.0).floor, 82].max, 128].min
    @slot_h = (@slot_w * 1.42).round
    @card_width = @slot_w - 2
    @card_height = @slot_h - 2

    @top_row_y = 20
    @tableau_y = @top_row_y + @slot_h + 52

    @board_width = board_padding + (7 * @slot_w) + (6 * @slot_gap) + board_padding
    needed = @tableau_y + @card_height + (6 * @card_offset) + 36
    @board_height = [needed, [screen_height - 120, 460].max].min

    @board_left = ((screen_width - @board_width) / 2.0).floor
    @board_left = 0 if @board_left < 0
  end

  def create_slots
    x0 = 12
    step = @slot_w + @slot_gap

    @stock = Slot.new(type: :stock, left: x0, top: @top_row_y, width: @slot_w, height: @slot_h, border: true)
    @waste = Slot.new(type: :waste, left: x0 + step, top: @top_row_y, width: @slot_w, height: @slot_h, border: false)

    @foundation = Array.new(4) do |i|
      Slot.new(type: :foundation, left: x0 + step * (3 + i), top: @top_row_y, width: @slot_w, height: @slot_h, border: false)
    end

    @tableau = Array.new(7) do |i|
      Slot.new(type: :tableau, left: x0 + step * i, top: @tableau_y, width: @slot_w, height: @slot_h, border: false)
    end

    @slots = [@stock, @waste] + @foundation + @tableau
  end

  def create_deck
    suites = [
      Suite.new("hearts", "RED"),
      Suite.new("diamonds", "RED"),
      Suite.new("clubs", "BLACK"),
      Suite.new("spades", "BLACK")
    ]
    ranks = [
      Rank.new("Ace", 1), Rank.new("2", 2), Rank.new("3", 3), Rank.new("4", 4),
      Rank.new("5", 5), Rank.new("6", 6), Rank.new("7", 7), Rank.new("8", 8),
      Rank.new("9", 9), Rank.new("10", 10), Rank.new("Jack", 11), Rank.new("Queen", 12), Rank.new("King", 13)
    ]

    @cards = suites.product(ranks).map do |suite, rank|
      Card.new(solitaire: self, suite: suite, rank: rank, width: @card_width, height: @card_height)
    end.shuffle
  end

  def deal_cards
    reset_deck_state!

    card_index = 0
    first_slot = 0

    while card_index <= 27
      (first_slot...@tableau.length).each do |slot_index|
        @cards[card_index].place(@tableau[slot_index])
        card_index += 1
      end
      first_slot += 1
    end

    @tableau.each do |slot|
      slot.top_card&.turn_face_up!
    end

    (28...@cards.length).each do |i|
      @cards[i].place(@stock)
    end

    @status_text = "Drag cards"
  end

  def render_scene
    @page.title = "Solitaire"
    @page.bgcolor = TABLE_BG
    @page.vertical_alignment = "start"
    @page.horizontal_alignment = "start"

    appbar = @page.app_bar(
      bgcolor: TABLE_BG,
      color: TITLE_COLOR,
      title: @page.text(value: "RubyNative Solitaire", color: TITLE_COLOR, size: 18)
    )

    @status_control = @page.text(value: @status_text, size: 12, color: STATUS_COLOR)

    controls = []
    controls << @stock.view(@page, on_click: ->(_e) { stock_click })
    controls << @waste.view(@page)
    controls.concat(@foundation.map { |s| s.view(@page) })
    controls.concat(@tableau.map { |s| s.view(@page) })
    controls.concat(@cards.map { |c| c.view(@page) }.compact)

    @page.add(
      @page.container(
        expand: true,
        bgcolor: TABLE_BG,
        padding: 10,
        content: @page.column(
          expand: true,
          spacing: 10,
          controls: [
            @status_control,
            @page.row(
              expand: true,
              alignment: "center",
              vertical_alignment: "start",
              controls: [
                @page.container(
                  width: @board_width,
                  height: @board_height,
                  content: @page.stack(controls: controls)
                )
              ]
            )
          ]
        )
      ),
      appbar: appbar
    )
  end

  def draw_from_stock
    return if @stock.pile.empty?

    hide_waste_preview

    [@waste_size, @stock.pile.length].min.times do
      top_card = @stock.top_card
      top_card.place(@waste)
      top_card.turn_face_up!
    end

    display_waste
    @status_text = "Draw"
    @page.update(@status_control, value: @status_text) if @status_control
  end

  def stock_click
    return unless @stock.pile.empty?
    return unless @deck_passes_remaining > 1

    @deck_passes_remaining -= 1
    restart_stock
    @status_text = "Restart stock"
    @page.update(@status_control, value: @status_text) if @status_control
  end

  def hide_waste_preview
    @waste.top_three_cards.each do |card|
      card.visible = false
      patch_card(card)
    end
  end

  def display_waste
    top_cards = @waste.top_three_cards
    top_cards.each_with_index do |card, idx|
      card.left = @waste.left + (idx * @card_offset)
      card.top = @waste.top + 3
      card.visible = true
      patch_card(card)
    end
  end

  def restart_stock
    @waste.pile.reverse_each do |card|
      card.turn_face_down!
      card.place(@stock)
    end
    @waste.pile.clear
  end

  def check_foundation_rules(current_card, top_card = nil)
    if top_card
      current_card.suite.name == top_card.suite.name && (current_card.rank.value - top_card.rank.value == 1)
    else
      current_card.rank.name == "Ace"
    end
  end

  def check_tableau_rules(current_card, top_card = nil)
    if top_card
      current_card.suite.color != top_card.suite.color && (top_card.rank.value - current_card.rank.value == 1)
    else
      current_card.rank.name == "King"
    end
  end

  def reveal_old_tableau_top(old_slot)
    return unless old_slot && old_slot.type == :tableau

    old_slot.top_card&.turn_face_up!
  end

  def reset_deck_state!
    (@slots || []).each { |s| s.pile.clear }
    @cards.each do |card|
      card.slot = nil
      card.face_up = false
      card.visible = true
      card.left = 0
      card.top = 0
    end
  end

  def candidate_slots
    @tableau + @foundation
  end

  def dig_number(data, *keys)
    value = keys.reduce(data) { |acc, k| acc.is_a?(Hash) ? acc[k] : nil }
    return 0.0 if value.nil?

    value.to_f
  rescue StandardError
    0.0
  end
end

class SolitaireApp < RubyNative::App
  def view(page)
    Solitaire.new(page)
  end
end

SolitaireApp.new.run
