require 'hiccdown'
require 'minitest/autorun'
require 'rails'
require 'action_controller/railtie'
# Hiccdown loads its railtie only when Rails is already loaded, which it isn't
# when the first line above runs.
require 'hiccdown/railtie'
require 'active_support/core_ext/string/output_safety'
require 'minitest/autorun'
require_relative 'factories/record'

class HiccdownTest < Minitest::Test
  class TestHelper
    # A view's output buffer, which Rails 7.0's helpers need.
    include ActionView::Context
    include ActionView::Helpers
    include Hiccdown::ViewHelpers
    include ActionDispatch::Routing::PolymorphicRoutes

    def _routes
      @_routes ||= ActionDispatch::Routing::RouteSet.new.tap do |r|
        r.draw do
          resources :records  # Add other resources as needed
        end
      end
    end

    def url_options
      {}
    end

    # Rails 7.0 passes options.
    def records_path(*)
      '/records'
    end
  end
end

# Runs a controller action as a request would, returning its status and body.
module ControllerRequests
  # The router would set the action in the params, which `routed: false`
  # leaves out.
  def request controller, action, routed: true
    env = Rack::MockRequest.env_for('/')
    env['action_dispatch.request.path_parameters'] = { action: action.to_s } if routed
    status, _headers, body = controller.action(action).call(env)
    html = +''
    body.each { |part| html << part }
    [status, html]
  end
end

# Create a minimal Rails application
class TestApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = 'test'
end

TestApp.initialize!
