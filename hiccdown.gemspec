Gem::Specification.new do |s|
  s.name        = 'hiccdown'
  s.version     = '1.5.4'
  s.summary     = 'Hiccup for Ruby'
  s.description = 'Generates an HTML string from a Hiccup structure and improves Rails views.'
  s.authors     = ['Dennis Hackethal']
  s.email       = 'engineering@dennishackethal.com'
  s.files       = Dir['lib/**/*']
  s.homepage    = 'https://github.com/dchacke/hiccdown'
  s.license     = 'MIT'

  # Tested against each of these with the Gemfiles in `gemfiles`.
  s.add_dependency 'actionview', '>= 7.0', '< 9'
  s.add_dependency 'activesupport', '>= 7.0', '< 9'
end
