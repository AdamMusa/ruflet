# frozen_string_literal: true

require "digest"

raise LoadError, "this VM build does not include Digest::SHA1" unless Digest.const_defined?(:SHA1)
