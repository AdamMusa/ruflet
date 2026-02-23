# frozen_string_literal: true

require_relative "../../icon_data"

module RubyNative
  module CupertinoIcons
    module_function

    ICONS = {
      ADD: "add",
      ADD_CIRCLED: "add_circled",
      MINUS: "minus",
      CHECK_MARK: "check_mark",
      CLEAR: "clear",
      XMARK: "xmark",
      SEARCH: "search",
      SETTINGS: "settings",
      HOME: "home",
      HEART: "heart",
      HEART_FILL: "heart_fill",
      STAR: "star",
      STAR_FILL: "star_fill",
      DELETE: "delete",
      PERSON: "person",
      PERSON_2: "person_2",
      MAIL: "mail",
      PHONE: "phone",
      LOCK: "lock",
      EYE: "eye",
      EYE_SLASH: "eye_slash",
      LEFT_CHEVRON: "left_chevron",
      RIGHT_CHEVRON: "right_chevron",
      UP_ARROW: "up_arrow",
      DOWN_ARROW: "down_arrow",
      REFRESH: "refresh",
      CLOUD_DOWNLOAD: "cloud_download",
      CLOUD_UPLOAD: "cloud_upload",
      PLAY: "play",
      PAUSE: "pause",
      STOP: "stop",
      FORWARD: "forward",
      BACK: "back",
      VOLUME_UP: "volume_up",
      VOLUME_OFF: "volume_off",
      PHOTO: "photo",
      CAMERA: "camera",
      VIDEOCAM: "videocam",
      FOLDER: "folder",
      CALENDAR: "calendar",
      CLOCK: "clock",
      CART: "cart",
      CREDITCARD: "creditcard",
      MONEY_DOLLAR: "money_dollar",
      GLOBE: "globe",
      LOCATION: "location",
      MAP: "map",
      MOON: "moon",
      SUN_MAX: "sun_max",
      HAMMER: "hammer",
      CHEVRON_UP_CHEVRON_DOWN: "chevron_up_chevron_down"
    }.freeze

    ICONS.each do |const_name, icon_name|
      const_set(const_name, RubyNative::IconData.new(icon_name))
    end

    def [](name)
      key = name.to_s.upcase.to_sym
      return const_get(key) if const_defined?(key, false)

      RubyNative::IconData.new(name.to_s)
    end
  end
end
