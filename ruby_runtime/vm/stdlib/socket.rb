# frozen_string_literal: true

# Socket classes (TCPServer, TCPSocket, ...) are provided natively by
# mruby-socket; requiring "socket" only needs to succeed.
raise LoadError, "this VM build does not include mruby-socket" unless Object.const_defined?(:TCPServer)
