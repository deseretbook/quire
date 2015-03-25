# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'quire/version'

Gem::Specification.new do |spec|
  spec.name          = 'quire'
  spec.version       = Quire::VERSION
  spec.authors       = ['Matthew Nielsen']
  spec.email         = ['mnielsen@deseretbook.com']
  spec.summary       = %q{Creates a smaller sample ePub from a larger ePub file.}
  spec.description   = %q{Creates a smaller sample ePub from a larger ePub file.}
  spec.homepage      = 'https://github.com/deseretbook/quire'
  spec.license       = 'PROPRIETARY'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # version here should match version used in bookshelf
  spec.add_runtime_dependency 'rubyzip', '~> 1.1', '>= 1.1.4'
  spec.add_runtime_dependency 'multi_xml', '~> 0.5', '>= 0.5.5'
  spec.add_runtime_dependency 'nokogiri', '~> 1.6', '>= 1.6.0'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake', '~> 0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'guard-rspec', '~> 4.2'
  spec.add_development_dependency 'debugger', '~> 1.6'
end
