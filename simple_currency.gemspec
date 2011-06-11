# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "simple_currency/version"

Gem::Specification.new do |s|
  s.name = "simple_currency"
  s.version = SimpleCurrency::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Oriol Gual", "Josep M. Bach", "Josep Jaume Rey"]
  s.email       = ["info@codegram.com"]
  s.homepage = %q{http://github.com/codegram/simple_currency}
  s.description = %q{A really simple currency converter using XavierMedia API. It's Ruby 1.8, 1.9 and JRuby compatible, and it also takes advantage of Rails cache when available.}
  s.summary = %q{A really simple currency converter using XavierMedia API.}

  s.add_dependency 'crack', [">= 0.1.8"]

  s.add_development_dependency 'minitest'
  s.add_development_dependency 'fakeweb', [">= 1.3.0"]
  s.add_development_dependency 'rails', "~> 3.0.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
