# -*- encoding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cache_failover/version"

Gem::Specification.new do |gem|
  gem.name = "cache_failover"
  gem.version = CacheFailover::VERSION
  gem.authors = ["Jamie Puckett"]
  gem.email = ["jamiep@supportabilit.com"]
  gem.summary = %q{ Failover Handling Cache Store for Rails w/ Brotli compression support. (Redis[Hiredis]/Memcached[Dalli]/SolidCache[MySQL/PG])  }
  gem.description = %q{ This gem enables automatic failover to a secondary caching method when the primary fails. }
  gem.homepage = "https://github.com/chronicaust/cache_failover"
  gem.files = Dir.glob('lib/**/*') + [
    'LICENSE',
    'README.md',
    'Gemfile'
  ]
  gem.license = "MIT"

  gem.add_dependency "activesupport"
  gem.add_dependency "brotli"
  gem.add_dependency "rails-brotli-cache"
  gem.add_dependency "msgpack"
  gem.add_development_dependency "solid_cache"
  gem.add_development_dependency "redis"
  gem.add_development_dependency "hiredis"
  gem.add_development_dependency "dalli"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "railties"
  gem.add_development_dependency "activemodel"
  gem.add_development_dependency "actionpack"
  gem.add_development_dependency "byebug"
  gem.add_development_dependency "rufo"
  gem.required_ruby_version = '>= 2.6'

  gem.metadata = {
    'bug_tracker_uri' => 'https://github.com/chronicaust/cache_failover/issues',
    'rubygems_mfa_required' => 'true'
  }
end