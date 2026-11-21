# frozen_string_literal: true

module Ruflet
  # Ids for the session_id a register_client reply hands the client.
  #
  # A host that resumes sessions (ruflet_rails' LocalServer) gives the live
  # Page to the client that presents its id, so an id has to be as hard to
  # guess as a session cookie: SecureRandom.uuid, which keeps the 8-4-4-4-12
  # hex shape clients already store. ruflet_core loads securerandom (see
  # Ruflet::Control); the embedded VM ships its own SecureRandom.
  module SessionId
    module_function

    def generate
      return SecureRandom.uuid if Object.const_defined?(:SecureRandom) && SecureRandom.respond_to?(:uuid)

      fallback
    end

    # Only for a Ruby without SecureRandom.
    def fallback
      format(
        "%08x-%04x-%04x-%04x-%012x",
        (rand(0..0xffff) << 16) | rand(0..0xffff),
        rand(0..0xffff),
        rand(0..0xffff),
        rand(0..0xffff),
        (rand(0..0xffff) << 32) | (rand(0..0xffff) << 16) | rand(0..0xffff)
      )
    end
  end
end
