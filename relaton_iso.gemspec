# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "relaton_iso/version"

Gem::Specification.new do |spec|
  spec.name          = "relaton-iso"
  spec.version       = RelatonIso::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "RelatonIso: retrieve ISO Standards for bibliographic " \
                       "use using the IsoBibliographicItem model"
  spec.description   = "RelatonIso: retrieve ISO Standards for bibliographic " \
                       "use using the IsoBibliographicItem model"

  spec.homepage      = "https://github.com/relaton/relaton-iso"
  spec.license       = "BSD-2-Clause"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.add_dependency "pubid", "~> 0.1.1"
  spec.add_dependency "relaton-index", "~> 0.2.12"
  spec.add_dependency "relaton-iso-bib", "~> 1.20.0"
end
