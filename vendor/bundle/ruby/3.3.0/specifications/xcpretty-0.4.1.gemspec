# -*- encoding: utf-8 -*-
# stub: xcpretty 0.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "xcpretty".freeze
  s.version = "0.4.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Marin Usalj".freeze, "Delisa Mason".freeze]
  s.date = "2025-03-26"
  s.description = "\n    Xcodebuild formatter designed to be piped with `xcodebuild`,\n    and thus keeping 100% compatibility.\n\n    It has modes for CI, running tests (RSpec dot-style),\n    and it can also mine Bitcoins.\n    ".freeze
  s.email = ["marin2211@gmail.com".freeze, "iskanamagus@gmail.com".freeze]
  s.executables = ["xcpretty".freeze]
  s.files = ["bin/xcpretty".freeze]
  s.homepage = "https://github.com/supermarin/xcpretty".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "3.2.32".freeze
  s.summary = "xcodebuild formatter done right".freeze

  s.installed_by_version = "3.6.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<rouge>.freeze, ["~> 3.28.0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 2.1.4".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.34.0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["= 2.99.0".freeze])
  s.add_development_dependency(%q<cucumber>.freeze, ["~> 1.0".freeze])
end
