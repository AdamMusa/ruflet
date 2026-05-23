# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

class RufletView
  attr_reader :page

  class << self
    def route(path = nil)
      @route_path = normalize_route(path) if path
      @route_path || inferred_route
    end

    def inherited(child)
      super
      Ruflet::Rails.register_view(child) if defined?(Ruflet::Rails)
    end

    private

    def inferred_route
      name_part = name.to_s.split("::").last.to_s.sub(/View\z/, "")
      path = name_part.underscore.pluralize
      normalize_route(path.empty? ? "/" : path)
    end

    def normalize_route(path)
      value = path.to_s.strip
      return "/" if value.empty? || value == "/"

      "/#{value.gsub(%r{\A/+|/+\z}, "")}"
    end
  end

  def self.render(page, *args, **kwargs, &block)
    new(page).render(*args, **kwargs, &block)
  end

  def initialize(page)
    @page = page
  end
end
