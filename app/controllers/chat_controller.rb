# frozen_string_literal: true

# ChatController needs ActionController::Base for HTML view rendering
# (ApplicationController inherits from ActionController::API)
class ChatController < ActionController::Base
  # Enable HAML template rendering
  layout 'application'

  # Disable CSRF for API-style chat endpoints
  skip_before_action :verify_authenticity_token, raise: false

  def show
    # Render the standard chat interface
  end

  def turbo
    # Render the Turbo Streams chat interface
  end

  def simple
    # Render the simple test chat interface
  end

  def mcp
    # Render the Seven Pools MCP-powered chat interface
  end
end