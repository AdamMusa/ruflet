# frozen_string_literal: true

module Ruflet
  # Raised by a page method the client's platform cannot perform, before
  # anything is sent (Flet's FletUnsupportedPlatformException).
  class UnsupportedPlatformError < StandardError; end

  # The physical orientations Page#set_allowed_device_orientations accepts
  # (Flet's DeviceOrientation). The constants are the wire values; the method
  # also takes the snake_case names as symbols or strings (:portrait_up).
  module DeviceOrientation
    PORTRAIT_UP = "portraitUp"
    PORTRAIT_DOWN = "portraitDown"
    LANDSCAPE_LEFT = "landscapeLeft"
    LANDSCAPE_RIGHT = "landscapeRight"

    ALL = [PORTRAIT_UP, PORTRAIT_DOWN, LANDSCAPE_LEFT, LANDSCAPE_RIGHT].freeze
    NAMES = %w[portrait_up portrait_down landscape_left landscape_right].freeze

    # "portraitup" => "portraitUp": every accepted spelling, with underscores
    # dropped and lowercased, maps to its wire value.
    LOOKUP = ALL.each_with_object({}) { |value, lookup| lookup[value.downcase] = value }.freeze

    # The wire value of one orientation; ArgumentError for anything else.
    def self.wire_value(orientation)
      value = LOOKUP[orientation.to_s.delete("_").downcase]
      return value if value

      raise ArgumentError,
            "unknown device orientation #{orientation.inspect}; expected one of #{NAMES.join(', ')}"
    end
  end

  # What Page#get_device_info answers: the client's device_info_plus record
  # (Flet's AndroidDeviceInfo, IosDeviceInfo, MacOsDeviceInfo,
  # WindowsDeviceInfo, LinuxDeviceInfo or WebDeviceInfo fields, snake_case,
  # plus "locales"), tagged with the platform that decides which fields exist.
  #
  #   info = page.get_device_info_sync
  #   info.platform           # => "android" ("web" in a browser)
  #   info.model              # => "Pixel 8" (any field, by name)
  #   info["version"]["sdk"]  # => 35 (nested records stay hashes)
  #   info.to_h               # => the whole record
  #
  # `platform` is the client platform ("android", "android_tv", "ios",
  # "macos", "windows", "linux", or "web"), not a record field: in a browser
  # the record's own navigator platform string is info["platform"].
  class DeviceInfo
    attr_reader :platform

    def initialize(platform:, data:)
      @platform = platform.nil? ? nil : platform.to_s
      @data = {}
      data.each { |key, value| @data[key.to_s] = value } if data.is_a?(Hash)
    end

    def [](key)
      @data[key.to_s]
    end

    def key?(key)
      @data.key?(key.to_s)
    end

    def keys
      @data.keys
    end

    def to_h
      @data.dup
    end

    def web?
      platform == "web"
    end

    # Android phones and tablets, and Android TV.
    def android?
      platform == "android" || platform == "android_tv"
    end

    def ios?
      platform == "ios"
    end

    def macos?
      platform == "macos"
    end

    def windows?
      platform == "windows"
    end

    def linux?
      platform == "linux"
    end

    # Android's "display" field (Object#display would print the object).
    def display(*args)
      return @data["display"] if args.empty? && @data.key?("display")

      super
    end

    def ==(other)
      other.is_a?(DeviceInfo) && other.platform == platform && other.to_h == @data
    end

    def inspect
      "#<Ruflet::DeviceInfo platform=#{platform.inspect} #{@data.inspect}>"
    end

    def method_missing(name, *args, &block)
      key = name.to_s
      return @data[key] if args.empty? && block.nil? && @data.key?(key)

      super
    end

    def respond_to_missing?(name, include_private = false)
      @data.key?(name.to_s) || super
    end
  end
end
