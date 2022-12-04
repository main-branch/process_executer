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
require 'simplecov-lcov'
require 'json'

SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::LcovFormatter]

# Fail the rspec run if code coverage falls below the configured threshold
#
# Skip this check if the NOCOV environment variable is set to TRUE
#
# ```Shell
# NOCOV=TRUE rspec
# ```
#
# Example of running the tests in an infinite loop writing failures to `fail.txt`:
#
# ```Shell
# while true; do
#   NOCOV=TRUE rspec spec/process_executer/monitored_pipe_spec.rb | sed -n '/^Failures:$/, /^Finished /p' >> fail.txt
# done
# ````
#
test_coverage_threshold = 100
SimpleCov.at_exit do
  unless RSpec.configuration.dry_run?
    SimpleCov.result.format!

    if ENV['NOCOV'] != 'TRUE' && SimpleCov.result.covered_percent < test_coverage_threshold
      warn "FAIL: RSpec Test coverage fell below #{test_coverage_threshold}%"

      warn "\nThe following lines were not covered by tests:\n"
      SimpleCov.result.files.each do |source_file| # SimpleCov::SourceFile
        source_file.missed_lines.each do |line| # SimpleCov::SourceFile::Line
          puts "  #{source_file.project_filename}:#{line.number}"
        end
      end
      warn "\n"

      exit 1
    end
  end
end

SimpleCov.start

# Make sure to require your project AFTER SimpleCov.start
#
require 'process_executer'
