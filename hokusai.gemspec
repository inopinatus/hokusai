# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hokusai/version'

Gem::Specification.new do |spec|
  spec.name          = "hokusai"
  spec.version       = Hokusai::VERSION
  spec.authors       = ["Josh Goodall"]
  spec.email         = ["inopinatus@inopinatus.org"]

  spec.summary       = %q{Stamp out your models.}
  spec.description   = %q{Stamp out copies of a model object, even after the original has departed, with these lightweight ActiveRecord concerns.}
  spec.homepage      = "https://github.com/inopinatus/hokusai"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "activerecord", "> 5.0"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "pry"
  spec.add_dependency "activesupport", "> 5.0"
end
