# frozen_string_literal: true

Rails.application.routes.draw do
  match "/ws", to: Ruflet::Rails.native(Rails.root.join("app/views/ruflet/main.rb")), via: :all
end
