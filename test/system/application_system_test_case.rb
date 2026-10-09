ENV['RAILS_ENV'] = 'test'

require_relative '../dummy/config/environment'
require 'rails/test_help'
require 'capybara/cuprite'

# Headless Brave, or another Chromium-based browser at BROWSER_PATH.
BROWSER_PATH = ENV.fetch('BROWSER_PATH', '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser')

Capybara.register_driver(:headless_browser) do |app|
  Capybara::Cuprite::Driver.new(app, browser_path: BROWSER_PATH, headless: true, window_size: [1200, 800])
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :headless_browser
end
