# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "vin/version"

Gem::Specification.new do |s|
  s.name = "hoov_vin"
  s.version = VIN::VERSION
  s.summary = "A Redis-powered Ruby ID generation client"
  s.description = "Generate unique, monotonically increasing integer IDs, designed for scalable distributed systems. Powered by Redis, drawing heavy inspiration from Icicle, Twitter Snowflake, and Dogtag."
  s.files = Dir["README.*", "lib/**/*.rb", "lua/**/*.lua.erb"]
  s.require_path = "lib"
  s.author = "Roger Oba"
  s.email = "roger@hoov.com.br"
  s.homepage = "https://github.com/hoovbr/vin"
  s.license = "MIT"
  s.add_dependency("redis", "~> 5")
  s.required_ruby_version = ">= 3.2"
  s.metadata["homepage_uri"] = s.homepage
  s.metadata["source_code_uri"] = "https://github.com/hoovbr/vin"
  s.metadata["changelog_uri"] = "https://github.com/hoovbr/vin/blob/main/CHANGELOG.md"
  # For more information and examples about making a new gem, check out our guide at: https://bundler.io/guides/creating_gem.html
  s.metadata["rubygems_mfa_required"] = "true"
end
