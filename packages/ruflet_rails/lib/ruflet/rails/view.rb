# frozen_string_literal: true

class RufletView
  attr_reader :page

  def self.render(page, *args, **kwargs, &block)
    new(page).render(*args, **kwargs, &block)
  end

  def initialize(page)
    @page = page
  end
end
