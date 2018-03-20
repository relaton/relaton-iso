
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "isobib/version"

Gem::Specification.new do |spec|
  spec.name          = "isobib"
  spec.version       = Isobib::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = 'IsoBib: retrieve ISO Standards for bibliographic use using the BibliographicItem model'
  spec.description   = 'IsoBib: retrieve ISO Standards for bibliographic use using the BibliographicItem model'

  spec.homepage      = "https://github.com/riboseinc/isobib"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov"
  # spec.add_development_dependency "byebug"
  spec.add_development_dependency "pry-byebug"

  spec.add_dependency "isoics"
  spec.add_dependency "algoliasearch"
  spec.add_dependency "nokogiri"
  # spec.add_dependency "capybara"
  # spec.add_dependency "poltergeist"
end

