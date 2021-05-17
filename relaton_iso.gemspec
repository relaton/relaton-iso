# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "relaton_iso/version"

Gem::Specification.new do |spec|
  spec.name          = "relaton-iso"
  spec.version       = RelatonIso::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "RelatonIso: retrieve ISO Standards for bibliographic use "\
                       "using the IsoBibliographicItem model"
  spec.description   = "RelatonIso: retrieve ISO Standards for bibliographic use "\
                       "using the IsoBibliographicItem model"

  spec.homepage      = "https://github.com/relaton/relaton-iso"
  spec.license       = "BSD-2-Clause"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.add_development_dependency "byebug"
  # spec.add_development_dependency "debase"
  spec.add_development_dependency "equivalent-xml", "~> 0.6"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  # spec.add_development_dependency "ruby-debug-ide"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"

  # spec.add_dependency "relaton-iec", "~> 1.8.0"
  spec.add_dependency "relaton-iso-bib", "~> 1.8.0"
end
