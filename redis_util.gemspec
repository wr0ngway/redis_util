# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis_util/version'

Gem::Specification.new do |spec|
  spec.name          = "redis_util"
  spec.version       = RedisUtil::VERSION
  spec.authors       = ["Matt Conway"]
  spec.email         = ["matt@conwaysplace.com"]
  spec.description   = %q{An aggregation of redis utility code, including a factory for tracking connections}
  spec.summary       = %q{Redis utilities}
  spec.homepage      = "http://github.com/wr0ngway/redis_util"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 4.0"
  spec.add_development_dependency "minitest_should"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "mocha"

  spec.add_dependency "gem_logger"
  spec.add_dependency "redis"
  spec.add_dependency "redis-namespace"
end
