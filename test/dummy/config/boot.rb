# The app runs on the gem's own bundle, with Hiccdown from this repository.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../Gemfile', __dir__)

require 'bundler/setup'
