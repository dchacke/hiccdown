require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task default: :test

desc 'Run tests against each supported version of Rails, with the Gemfiles in gemfiles/'
task 'test:rails' do
  Dir['gemfiles/*.gemfile'].sort.push('Gemfile').each do |gemfile|
    puts "\n== #{gemfile}"
    env = { 'BUNDLE_GEMFILE' => File.expand_path(gemfile) }
    sh(env, 'bundle install --quiet && bundle exec rake test')
  end
end
