# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      # Base controller for API v1 endpoints
      # Maintains API-only behavior for API endpoints
      # Can include common API functionality like authentication, versioning, etc.
    end
  end
end