# coding: utf-8
require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "simple_currency"
    gem.summary = "A really simple currency converter using the Xurrency API."
    gem.description = "A really simple currency converter using the Xurrency API. It's Ruby 1.8, 1.9 and JRuby compatible, and it also takes advantage of Rails cache when available."
    gem.email = "info@codegram.com"
    gem.homepage = "http://github.com/codegram/simple_currency"
    gem.authors = ["Oriol Gual", "Josep M. Bach", "Josep Jaume Rey"]

    gem.add_dependency 'json', ">= 1.4.3"

    gem.add_development_dependency "jeweler", '>= 1.4.0'
    gem.add_development_dependency "rspec", '>= 2.0.0.beta.20'
    gem.add_development_dependency "fakeweb", '>= 1.3.0'
    gem.add_development_dependency "rails", '>= 3.0.0'
    gem.add_development_dependency "bundler", '>= 1.0.0'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

# Rake RSpec2 task stuff
gem 'rspec', '>= 2.0.0.beta.20'
gem 'rspec-expectations'

require 'rspec/core/rake_task'

desc "Run the specs under spec"
RSpec::Core::RakeTask.new do |t|
end

task :default => :spec
