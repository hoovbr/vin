require "bundler/setup"
require "date"
require "dotenv"
require "rspec"
require "simplecov"

# Must be in this particular order
Dotenv.load("spec/support/.env.test")
require "vin"

SimpleCov.start

Dir["./spec/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  # Display warnings if there are any
  config.warnings = true
end
