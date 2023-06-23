# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'clowder-common-ruby/version'

Gem::Specification.new do |spec|
  spec.name          = "clowder-common-ruby"
  spec.version       = ClowderCommonRuby::VERSION
  spec.authors       = ["Red Hat Developers"]

  spec.summary       = %q{Supporting files and libraries for Clowder environmental variables.}
  spec.description   = %q{This is a ruby interface for preparing Clowder variables.}
  spec.homepage      = "https://github.com/RedHatInsights/clowder-common-ruby"
  spec.license       = "Apache-2.0"

  spec.files = Dir["{bin,lib,config}/**/*", "LICENSE.txt", "Rakefile", "README.md", "sync_config.sh", "test.json"]
end
