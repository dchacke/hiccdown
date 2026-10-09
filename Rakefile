require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task default: :test

# Slower, since they drive a headless browser through the app in test/dummy,
# so they don't run with the others.
Rake::TestTask.new('test:system') do |t|
  t.libs << 'test'
  t.pattern = 'test/system/**/*_test.rb'
  t.description = 'Run the system tests in a headless browser'
end

desc 'Run tests against each supported version of Rails, with the Gemfiles in gemfiles/'
task 'test:rails' do
  failed = Dir['gemfiles/*.gemfile'].sort.push('Gemfile').reject do |gemfile|
    puts "\n== #{gemfile}"
    env = { 'BUNDLE_GEMFILE' => File.expand_path(gemfile) }
    sh(env, 'bundle install --quiet && bundle exec rake test') { |ok, _| ok }
  end

  abort "\nFailed with #{failed.join(', ')}" if failed.any?
end
