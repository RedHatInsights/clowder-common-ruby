# -*- encoding: utf-8 -*-
# stub: actionview 6.1.7.10 ruby lib

Gem::Specification.new do |s|
  s.name = "actionview".freeze
  s.version = "6.1.7.10".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/rails/rails/issues", "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.7.10/actionview/CHANGELOG.md", "documentation_uri" => "https://api.rubyonrails.org/v6.1.7.10/", "mailing_list_uri" => "https://discuss.rubyonrails.org/c/rubyonrails-talk", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.7.10/actionview" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2024-10-23"
  s.description = "Simple, battle-tested conventions and helpers for building web pages.".freeze
  s.email = "david@loudthinking.com".freeze
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.requirements = ["none".freeze]
  s.rubygems_version = "3.4.22".freeze
  s.summary = "Rendering framework putting the V in MVC (part of Rails).".freeze

  s.installed_by_version = "3.4.22".freeze if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.7.10".freeze])
  s.add_runtime_dependency(%q<builder>.freeze, ["~> 3.1".freeze])
  s.add_runtime_dependency(%q<erubi>.freeze, ["~> 1.4".freeze])
  s.add_runtime_dependency(%q<rails-html-sanitizer>.freeze, ["~> 1.1".freeze, ">= 1.2.0".freeze])
  s.add_runtime_dependency(%q<rails-dom-testing>.freeze, ["~> 2.0".freeze])
  s.add_development_dependency(%q<actionpack>.freeze, ["= 6.1.7.10".freeze])
  s.add_development_dependency(%q<activemodel>.freeze, ["= 6.1.7.10".freeze])
end
