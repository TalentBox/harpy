# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "harpy/version"

Gem::Specification.new do |s|
  s.name        = "harpy"
  s.version     = Harpy::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Joseph HALTER", "Jonathan TRON"]
  s.email       = ["joseph.halter@thetalentbox.com", "jonathan.tron@thetalentbox.com"]
  s.homepage    = "https://github.com/TalentBox/harpy"
  s.summary     = %q{Client for REST API}
  s.description = %q{Client for REST API with HATEOAS}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency("typhoeus", ["~> 0.3.3"])
  s.add_runtime_dependency("activesupport", [">= 3.1.0"])
  s.add_runtime_dependency("activemodel", [">= 3.1.0"])
  s.add_runtime_dependency("hash-deep-merge", ["~> 0.1.1"])
  s.add_runtime_dependency("yajl-ruby", ["~> 0.8.2"])

  s.add_development_dependency("rake", [">= 0.8.7"])
  s.add_development_dependency("rspec", ["~> 2.6.0"])
  s.add_development_dependency("rocco", ["~> 0.7"])
end
