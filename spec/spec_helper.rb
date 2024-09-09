# frozen_string_literal: true

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

require 'simplecov'
require 'simplecov-lcov'
require 'simplecov-rspec'

if ENV.fetch('GITHUB_ACTIONS', 'false') == 'true'
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
end

SimpleCov::RSpec.start

# Make sure to require your project AFTER starting SimpleCov
#
require 'process_executer'
