# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'experella-proxy/version'

Gem::Specification.new do |spec|
  spec.name          = "experella-proxy"
  spec.version       = ExperellaProxy::VERSION
  spec.authors       = ["Dennis-Florian Herr"]
  spec.email         = ["dennis.herr@experteer.com"]
  spec.description   = 'a balancing & routing proxy, see README for more details'
  spec.summary       = 'experella-proxy gem'
  spec.homepage      = "https://github.com/experteer/experella-proxy"
  spec.license       = "MIT"

  spec.add_runtime_dependency "daemons", "~> 1.1.4"
  spec.add_runtime_dependency "eventmachine", "~> 1.0.3"
  spec.add_runtime_dependency "http_parser.rb", "~> 0.5.3"

  spec.add_development_dependency "rake", "~> 10.1.0"
  # specs
  spec.add_development_dependency "rspec", "2.14.1"
  spec.add_development_dependency "posix-spawn"
  spec.add_development_dependency "em-http-request"
  # dev testing
  spec.add_development_dependency "sinatra", "1.4.3"
  spec.add_development_dependency "thin", "~> 1.5.1"
  # documentation tool
  spec.add_development_dependency "yard", "~> 0.8.7.3"
  spec.add_development_dependency "redcarpet", "~> 2.3.0"
  # code coverage
  spec.add_development_dependency "simplecov", "~> 0.7.1"

  spec.files         = Dir["bin/*"] + Dir["dev/*"] + Dir["lib/**/*"] + Dir["config/default/**/*"]
  spec.files        += Dir["spec/**/*"] + Dir["test/sinatra/*"]
  spec.files        += [".gitignore", "Gemfile", "experella-proxy.gemspec", "README.md", "TODO.txt", "Rakefile"]
  spec.executables   = spec.files.grep(%r{^bin/}){ |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec)/})
  spec.extra_rdoc_files = ['README.md']
  spec.require_paths = ["lib"]
end
