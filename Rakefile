require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task default: :test

desc 'Run tests against each supported version of Rails, with the Gemfiles in gemfiles/'
task 'test:rails' do
  failed = Dir['gemfiles/*.gemfile'].sort.push('Gemfile').reject do |gemfile|
    puts "\n== #{gemfile}"
    env = { 'BUNDLE_GEMFILE' => File.expand_path(gemfile) }
    sh(env, 'bundle install --quiet && bundle exec rake test') { |ok, _| ok }
  end

  abort "\nFailed with #{failed.join(', ')}" if failed.any?
end
