# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # About box with the open-source licenses page. Shown like any dialog:
        # page.show_dialog(about_dialog(...)). view: "licenses" opens the
        # licenses page directly.
        class AboutDialogControl < Ruflet::Control
          TYPE = "aboutdialog".freeze
          WIRE = "AboutDialog".freeze

          KEYWORDS = [:application_icon, :application_legalese, :application_name, :application_version, :barrier_color, :controls, :data, :key, :modal, :open, :view, :visible, :on_dismiss].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            application_icon = props[:application_icon]
            application_legalese = props[:application_legalese]
            application_name = props[:application_name]
            application_version = props[:application_version]
            barrier_color = props[:barrier_color]
            controls = props[:controls]
            data = props[:data]
            key = props[:key]
            modal = props[:modal]
            open = props[:open]
            view = props[:view]
            visible = props[:visible]
            on_dismiss = props[:on_dismiss]

            props = {}
            props[:application_icon] = application_icon unless application_icon.nil?
            props[:application_legalese] = application_legalese unless application_legalese.nil?
            props[:application_name] = application_name unless application_name.nil?
            props[:application_version] = application_version unless application_version.nil?
            props[:barrier_color] = barrier_color unless barrier_color.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:modal] = modal unless modal.nil?
            props[:open] = open unless open.nil?
            props[:view] = view unless view.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
