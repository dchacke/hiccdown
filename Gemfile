source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.11'

gemspec

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rails', '~> 8.1.0'

  # The app in test/dummy, and its system tests
  gem 'capybara'
  gem 'cuprite'
  gem 'importmap-rails'
  gem 'propshaft'
  gem 'puma'
end
