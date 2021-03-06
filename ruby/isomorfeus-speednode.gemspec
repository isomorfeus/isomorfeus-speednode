require './lib/isomorfeus/speednode/version'

Gem::Specification.new do |s|
  s.name         = 'isomorfeus-speednode'
  s.version      = Isomorfeus::Speednode::VERSION
  s.author       = 'Jan Biedermann'
  s.email        = 'jan@kursator.de'
  s.homepage     = 'http://isomorfeus.com'
  s.license      = 'MIT'
  s.summary      = 'A fast ExecJS runtime based on nodejs, tuned for Isomorfeus.'
  s.description  = 'A fast ExecJS runtime based on nodejs, tuned for Isomorfeus.'
  s.metadata      = { "github_repo" => "ssh://github.com/isomorfeus/gems" }
  s.files          = `git ls-files -- lib LICENSE README.md`.split("\n")
  s.require_paths  = ['lib']

  s.add_dependency 'execjs', '~> 2.8.0'
  s.add_dependency 'oj', '>= 3.11.0'
  s.add_dependency 'win32-pipe', '>= 0.4.0'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest', '~> 5.14.4'
  s.add_development_dependency 'rake'
end
