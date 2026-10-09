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

    def records_path
      '/records'
    end
  end
end

# Runs a controller action as a request would, returning its status and body.
module ControllerRequests
  def request controller, action
    # Hiccdown finds the action's helper method by the action in the params,
    # which the router would otherwise set.
    env = Rack::MockRequest.env_for('/', 'action_dispatch.request.path_parameters' => { action: action.to_s })
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
