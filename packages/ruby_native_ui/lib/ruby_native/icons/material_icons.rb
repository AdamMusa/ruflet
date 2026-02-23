# frozen_string_literal: true

require_relative "../icon_data"

module RubyNative
  module MaterialIcons
    module_function

    ICONS = {
      ADD: "add",
      REMOVE: "remove",
      CHECK: "check",
      CLOSE: "close",
      MENU: "menu",
      SEARCH: "search",
      SETTINGS: "settings",
      HOME: "home",
      FAVORITE: "favorite",
      FAVORITE_BORDER: "favorite_border",
      STAR: "star",
      STAR_BORDER: "star_border",
      DELETE: "delete",
      EDIT: "edit",
      SAVE: "save",
      INFO: "info",
      WARNING: "warning",
      ERROR: "error",
      HELP: "help",
      LOGIN: "login",
      LOGOUT: "logout",
      PERSON: "person",
      GROUP: "group",
      EMAIL: "email",
      PHONE: "phone",
      LOCK: "lock",
      VISIBILITY: "visibility",
      VISIBILITY_OFF: "visibility_off",
      ARROW_BACK: "arrow_back",
      ARROW_FORWARD: "arrow_forward",
      ARROW_UPWARD: "arrow_upward",
      ARROW_DOWNWARD: "arrow_downward",
      CHEVRON_LEFT: "chevron_left",
      CHEVRON_RIGHT: "chevron_right",
      KEYBOARD_ARROW_UP: "keyboard_arrow_up",
      KEYBOARD_ARROW_DOWN: "keyboard_arrow_down",
      REFRESH: "refresh",
      DOWNLOAD: "download",
      UPLOAD: "upload",
      FILE_DOWNLOAD: "file_download",
      FILE_UPLOAD: "file_upload",
      PLAY_ARROW: "play_arrow",
      PAUSE: "pause",
      STOP: "stop",
      SKIP_NEXT: "skip_next",
      SKIP_PREVIOUS: "skip_previous",
      VOLUME_UP: "volume_up",
      VOLUME_OFF: "volume_off",
      IMAGE: "image",
      PHOTO_CAMERA: "photo_camera",
      VIDEO_CALL: "video_call",
      FOLDER: "folder",
      FOLDER_OPEN: "folder_open",
      CALENDAR_MONTH: "calendar_month",
      DATE_RANGE: "date_range",
      ACCESS_TIME: "access_time",
      SHOPPING_CART: "shopping_cart",
      PAYMENT: "payment",
      ATTACH_MONEY: "attach_money",
      LANGUAGE: "language",
      LOCATION_ON: "location_on",
      MAP: "map",
      DARK_MODE: "dark_mode",
      LIGHT_MODE: "light_mode",
      BUILD: "build",
      CODE: "code"
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
