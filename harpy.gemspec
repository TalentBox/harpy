# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "harpy"

Gem::Specification.new do |s|
  s.name        = "harpy"
  s.version     = Harpy::VERSION::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Joseph HALTER", "Jonathan TRON"]
  s.email       = ["joseph.halter@thetalentbox.com", "jonathan.tron@thetalentbox.com"]
  s.homepage    = "https://github.com/TalentBox/harpy"
  s.summary     = %q{Client for REST API}
  s.description = %q{Client for REST API with HATEOAS}
  s.license     = "MIT"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "typhoeus", ">= 0.6.5"
  s.add_runtime_dependency "activesupport", [">= 5.2.0"]
  s.add_runtime_dependency "activemodel", [">= 5.2.0"]
  s.add_runtime_dependency "hash-deep-merge", [">= 0.1.1"]

  s.add_development_dependency "rake", [">= 0.8.7"]
  s.add_development_dependency "rspec"
end
