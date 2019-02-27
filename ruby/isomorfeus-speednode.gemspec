require './lib/isomorfeus/speednode/version'

Gem::Specification.new do |s|
  s.name         = 'isomorfeus-speednode'
  s.version      = Isomorfeus::Speednode::VERSION
  s.author       = 'Jan Biedermann'
  s.email        = 'jan@kursator.de'
  s.homepage     = 'http://isomorfeus.com'
  s.license      = 'MIT'
  s.summary      = 'ExecJS runtime, tuned for Isomorfeus.'
  s.description  = 'ExecJS runtime, tuned for Isomorfeus.'

  s.files          = `git ls-files`.split("\n")
  s.test_files     = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths  = ['lib']

  s.add_dependency 'execjs', '~> 2.7.0'
  s.add_dependency 'oj', '~> 3.6.0'
end
