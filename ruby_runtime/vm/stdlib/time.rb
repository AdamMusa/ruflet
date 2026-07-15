# frozen_string_literal: true

# Time is provided natively by mruby-time; requiring "time" only needs to succeed.
raise LoadError, "this VM build does not include mruby-time" unless Object.const_defined?(:Time)
