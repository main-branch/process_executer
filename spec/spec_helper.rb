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

def windows?
  RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
end

def ruby_command(code)
  @ruby_path ||=
    if Gem.win_platform?
      `where ruby`.chomp
    else
      `which ruby`.chomp
    end

  [@ruby_path, '-e', code]
end

# SimpleCov configuration
#
require 'simplecov'
require 'simplecov-lcov'
require 'simplecov-rspec'

def ci_build? = ENV.fetch('GITHUB_ACTIONS', 'false') == 'true'

if ci_build?
  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
end

require 'rbconfig'

SimpleCov::RSpec.start(list_uncovered_lines: ci_build?) do
  # Avoid false positives in spec directory from JRuby, TruffleRuby, and Windows
  add_filter '/spec/' unless RUBY_ENGINE == 'ruby' && !Gem.win_platform?
end

# Make sure to require your project AFTER starting SimpleCov
#
require 'process_executer'
