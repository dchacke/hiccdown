require 'hiccdown'
require 'minitest/autorun'
require 'rails'
require 'action_controller/railtie'
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

# Create a minimal Rails application
class TestApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = 'test'
end

TestApp.initialize!
