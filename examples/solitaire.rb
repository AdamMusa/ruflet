require "ruflet"
Suite = Struct.new(:name, :color)
Rank = Struct.new(:name, :value)
class Slot
  attr_reader :type, :left, :top, :width, :height, :pile
  def initialize(type:, left:, top:, width:, height:, border: true)
    @type, @left, @top, @width, @height, @border = type, left, top, width, height, border
    @pile = []
  end
  def add(card); @pile << card; end
  def remove(card); @pile.delete(card); end
  def top_card; @pile.last; end
  def snap_top(offset); type == :tableau && @pile.length > 1 ? top + offset * (@pile.length - 1) : top; end
  def view(page, on_click: nil)
    p = { left: left, top: top, width: width, height: height, border_radius: 12, bgcolor: "#cfccd2" }
    p[:border] = { width: 1, color: "#b9b6be" } if @border
    p[:on_click] = on_click if on_click
    page.container(**p, content: page.text(value: "", size: 1))
  end
end
class Card
  RANK_CODE = { "Ace" => "A", "Jack" => "J", "Queen" => "Q", "King" => "K" }.freeze
  SUIT_CODE = { "spades" => "S", "hearts" => "H", "diamonds" => "D", "clubs" => "C" }.freeze
  attr_reader :suite, :rank, :control
  attr_accessor :left, :top, :slot, :face_up, :visible
  def initialize(game:, suite:, rank:, w:, h:)
    @game, @suite, @rank, @w, @h = game, suite, rank, w, h
    @slot, @face_up, @visible, @left, @top = nil, false, true, 0, 0
    @origin_left, @origin_top, @control = 0, 0, nil
  end
  def can_move?
    return false unless visible && slot
    slot.type == :waste ? slot.top_card == self : face_up
  end
  def moving_group; return [self] unless slot && slot.type == :tableau; i = slot.pile.index(self); i ? slot.pile[i..-1] : [self]; end
  def remember_origin; @origin_left, @origin_top = left, top; end
  def turn_up!; @face_up = true; @game.patch(self); end
  def turn_down!; @face_up = false; @visible = true; @game.patch(self); end
  def bounce_back!
    moving_group.each_with_index do |c, i|
      c.left = @origin_left
      c.top = @origin_top + (slot.type == :tableau ? i * @game.card_offset : 0)
      @game.patch(c)
    end
  end
  def place(dst)
    slot.remove(self) if slot
    @slot = dst
    @left = dst.left
    @top = dst.top + (dst.type == :tableau ? @game.card_offset * dst.pile.length : 0)
    dst.add(self)
    @game.raise_cards([self])
    @game.patch(self)
  end
  def code; r = RANK_CODE.fetch(rank.name, rank.name); r = "0" if rank.name == "10"; "#{r}#{SUIT_CODE.fetch(suite.name)}"; end
  def image_url
    face_up ? "https://deckofcardsapi.com/static/img/#{code}.png" : "https://deckofcardsapi.com/static/img/back.png"
  end
  def view(page)
    return nil unless visible
    @control ||= page.gesture_detector(
      left: left, top: top, visible: visible,
      on_pan_start: ->(_e) { @game.start_drag(self) },
      on_pan_update: ->(e) { @game.drag(self, e) },
      on_pan_end: ->(_e) { @game.drop(self) },
      on_tap: ->(_e) { @game.card_tap(self) },
      on_double_tap: ->(_e) { @game.card_double_tap(self) },
      content: page.image(image_url, width: @w, height: @h, fit: "fill")
    )
  end
end
class Solitaire
  TABLE_BG = "#d9d7db".freeze
  TITLE = "#232329".freeze
  STATUS = "#4d4c57".freeze
  attr_reader :card_offset
  def initialize(page)
    @page, @status, @passes = page, "Drag cards", 3
    @cards, @drag_cards = [], []
    setup_layout
    create_slots
    create_deck
    deal
    render
  end
  def start_drag(card)
    return unless card.can_move?
    @drag_cards = card.moving_group
    raise_cards(@drag_cards)
    card.remember_origin
    set_status("Dragging #{card.rank.name} #{card.suite.name}")
  end
  def drag(card, event)
    return unless card.can_move?
    return if @drag_cards.empty?
    dx, dy = n(event.data, "ld", "x"), n(event.data, "ld", "y")
    return if dx.zero? && dy.zero?
    x, y = card.left + dx, card.top + dy
    @drag_cards.each_with_index do |c, i|
      c.left = x
      c.top = y + (c.slot.type == :tableau ? i * @card_offset : 0)
      patch(c)
    end
  end
  def drop(card)
    return unless card.can_move?
    return if @drag_cards.empty?
    target = candidate_slots.find do |s|
      near = (card.left - s.left).abs <= @drop_proximity && (card.top - s.snap_top(@card_offset)).abs <= @drop_proximity
      ok_t = s.type == :tableau && valid_tableau?(card, s.top_card)
      ok_f = s.type == :foundation && @drag_cards.length == 1 && valid_foundation?(card, s.top_card)
      near && (ok_t || ok_f)
    end
    if target
      old = card.slot
      @drag_cards.each { |c| c.place(target) }
      old.top_card.turn_up! if old && old.type == :tableau && old.top_card
      set_status("Moved #{card.rank.name} #{card.suite.name}")
    else
      card.bounce_back!
      set_status("Invalid move")
    end
    @drag_cards = []
  end
  def card_tap(card)
    if card.slot.type == :stock
      stock_click
    elsif card.slot.type == :tableau
      t = card.slot.top_card
      t.turn_up! if t == card && !card.face_up
    end
  end
  def card_double_tap(card)
    return unless [:waste, :tableau].include?(card.slot.type) && card.face_up
    old = card.slot
    raise_cards([card])
    @foundation.each do |s|
      next unless valid_foundation?(card, s.top_card)
      card.place(s)
      old.top_card.turn_up! if old.type == :tableau && old.top_card
      return set_status("Moved to foundation")
    end
  end
  def patch(card)
    return unless card.control
    @page.update(card.control, left: card.left, top: card.top, visible: card.visible)
    @page.update(card.control.children.first, src: card.image_url) rescue nil
  end
  def raise_cards(cards)
    cards.each { |c| @cards.delete(c) }
    @cards.concat(cards)
  end
  private
  def set_status(text)
    @status = text
    @page.update(@status_control, value: @status) if @status_control
  end
  def setup_layout
    w, h = viewport("width"), viewport("height")
    w, h = [w / 2.0, h / 2.0] if w > 700 && h > 1000
    compact = w <= 520
    outer = compact ? 6 : 10
    avail_w = [w - 2 * outer - (compact ? 10 : 8), 310].max
    gap = compact ? 4 : 10
    @slot_w = ((avail_w - 6 * gap) / 7.0).floor
    @slot_w = [[@slot_w, 42].max, 56].min
    gap = ((avail_w - 7 * @slot_w) / 6.0).floor
    gap = [[gap, compact ? 3 : 8].max, 20].min
    @step = @slot_w + gap
    @slot_h = (@slot_w * 1.42).round
    @top_y = compact ? 10 : 16
    @tableau_y = @top_y + @slot_h + (compact ? 22 : 34)
    @card_offset = [(@slot_h * 0.30).round, 14].max
    @drop_proximity = [(@slot_w * 0.50).round, 14].max
    @board_w = 7 * @slot_w + 6 * gap
    need_h = @tableau_y + @slot_h + 6 * @card_offset + 20
    max_h = [(h * 0.52).round, 320].max
    @board_h = [need_h, max_h].min
    @outer = outer
  end
  def create_slots
    @stock = Slot.new(type: :stock, left: 0, top: @top_y, width: @slot_w, height: @slot_h, border: true)
    @waste = Slot.new(type: :waste, left: @step, top: @top_y, width: @slot_w, height: @slot_h, border: false)
    @foundation = (0...4).map { |i| Slot.new(type: :foundation, left: @step * (3 + i), top: @top_y, width: @slot_w, height: @slot_h, border: false) }
    @tableau = (0...7).map { |i| Slot.new(type: :tableau, left: @step * i, top: @tableau_y, width: @slot_w, height: @slot_h, border: false) }
  end
  def create_deck
    suites = [Suite.new("hearts", "RED"), Suite.new("diamonds", "RED"), Suite.new("clubs", "BLACK"), Suite.new("spades", "BLACK")]
    ranks = [["Ace",1],["2",2],["3",3],["4",4],["5",5],["6",6],["7",7],["8",8],["9",9],["10",10],["Jack",11],["Queen",12],["King",13]].map { |n,v| Rank.new(n,v) }
    @cards = suites.product(ranks).map { |s, r| Card.new(game: self, suite: s, rank: r, w: @slot_w, h: @slot_h) }.shuffle
  end
  def deal
    (@tableau + @foundation + [@stock, @waste]).each { |s| s.pile.clear }
    @cards.each { |c| c.slot = nil; c.face_up = false; c.visible = true; c.left = 0; c.top = 0 }
    idx = 0
    (0...7).each do |start|
      (start...7).each { |i| @cards[idx].place(@tableau[i]); idx += 1 }
    end
    @tableau.each { |t| t.top_card.turn_up! if t.top_card }
    (idx...@cards.length).each { |i| @cards[i].place(@stock) }
  end
  def render
    @page.title = "Solitaire"; @page.bgcolor = TABLE_BG; @page.vertical_alignment = "start"; @page.horizontal_alignment = "start"
    appbar = @page.app_bar(bgcolor: TABLE_BG, color: TITLE, title: @page.text(value: "Ruflet Solitaire", color: TITLE, size: 18))
    @status_control = @page.text(value: @status, size: 12, color: STATUS)
    controls = [@stock.view(@page, on_click: ->(_e) { stock_click }), @waste.view(@page)]
    controls.concat(@foundation.map { |s| s.view(@page) })
    controls.concat(@tableau.map { |s| s.view(@page) })
    controls.concat(@cards.map { |c| c.view(@page) }.compact)
    board = @page.container(width: @board_w, height: @board_h, content: @page.stack(controls: controls))
    body = @page.container(expand: true, bgcolor: TABLE_BG, padding: @outer, content: @page.column(expand: true, spacing: 10, controls: [@status_control, board]))
    @page.add(body, appbar: appbar)
  end
  def stock_click
    if @stock.pile.any?
      c = @stock.top_card; c.place(@waste); c.turn_up!
      return set_status("Draw")
    end
    return unless @waste.pile.any? && @passes > 1
    @passes -= 1
    @waste.pile.reverse_each { |c| c.turn_down!; c.place(@stock) }
    @waste.pile.clear
    set_status("Restart stock")
  end
  def valid_foundation?(card, top)
    top ? card.suite.name == top.suite.name && (card.rank.value - top.rank.value == 1) : card.rank.name == "Ace"
  end
  def valid_tableau?(card, top)
    top ? top.face_up && card.suite.color != top.suite.color && (top.rank.value - card.rank.value == 1) : card.rank.name == "King"
  end
  def candidate_slots; @tableau + @foundation; end
  def viewport(axis)
    vals = [n(@page.client_details, axis), n(@page.client_details, "media", "size", axis)].select { |v| v > 0 }
    vals.empty? ? (axis == "width" ? 390.0 : 760.0) : vals.min
  end
  def n(data, *keys)
    v = keys.reduce(data) { |a, k| a.is_a?(Hash) ? a[k] : nil }
    v ? v.to_f : 0.0
  rescue StandardError
    0.0
  end
end
class SolitaireApp < Ruflet::App
  def view(page); Solitaire.new(page); end
end
SolitaireApp.new.run
