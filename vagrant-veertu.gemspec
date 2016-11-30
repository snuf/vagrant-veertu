# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vagrant-veertu/version'

Gem::Specification.new do |spec|
  spec.name          = "vagrant-veertu"
  spec.version       = Vagrant::Veertu::VERSION
  spec.authors       = ["Veertu Labs"]
  spec.email         = ["support@veertu.com"]
  spec.summary       = %q{A Vagrant provider for Veertu}
  spec.homepage      = "http://veertu.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "inifile"
  spec.add_development_dependency "rake", "~> 10.0"
end
