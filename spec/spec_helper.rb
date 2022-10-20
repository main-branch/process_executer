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

# Setup simplecov

require 'simplecov'

SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter]

# Fail the rspec run if code coverage falls below the configured threshold
#
test_coverage_threshold = 100
SimpleCov.at_exit do
  unless RSpec.configuration.dry_run?
    SimpleCov.result.format!
    if SimpleCov.result.covered_percent < test_coverage_threshold
      warn "FAIL: RSpec Test coverage fell below #{test_coverage_threshold}%"
      exit 1
    end
  end
end

SimpleCov.start

# Make sure to require your project AFTER SimpleCov.start
#
require 'process_executer'
