# frozen_string_literal: true

require "ruflet"

Ruflet.run do |page|
  status = text(value: "in-process bridge ready")
  page.add(status)

  Thread.new do
    sleep 0.02
    page.update(status, value: "in-process background task advanced")
  end
end
