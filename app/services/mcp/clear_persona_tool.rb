# frozen_string_literal: true

module Mcp
  class ClearPersonaTool
    def self.call
      # Since we don't maintain server-side session state,
      # this is primarily a client-side operation.
      # We just return success to indicate the persona should be cleared.
      
      Rails.logger.info "ClearPersonaTool: Persona cleared"
      
      {
        ok: true,
        message: "Persona style cleared",
        meta: {
          timestamp: Time.current.iso8601,
          action: "clear_persona"
        }
      }
    rescue => e
      Rails.logger.error "ClearPersonaTool error: #{e.message}"
      
      {
        ok: false,
        error: "Failed to clear persona: #{e.message}",
        meta: {
          timestamp: Time.current.iso8601,
          action: "clear_persona"
        }
      }
    end
  end
end