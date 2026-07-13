# frozen_string_literal: true

# The Digest module is provided natively; requiring "digest" only needs to succeed.
raise LoadError, "this VM build does not include Digest" unless Object.const_defined?(:Digest)
