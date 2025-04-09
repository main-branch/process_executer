# frozen_string_literal: true

require 'rspec'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.after(:each) do
    # Make sure there are no open instance of ProcessExecuter::MonitoredPipe
    # after each test
    ProcessExecuter::MonitoredPipe.assert_no_open_instances
  end
end

# Check if the Ruby interpreter is JRuby or TruffleRuby
def truffleruby? = RUBY_ENGINE == 'truffleruby'
def jruby? = RUBY_ENGINE == 'jruby'
def mri? = RUBY_ENGINE == 'ruby'

if jruby?
  require 'java'
  def os_name = (@os_name = java.lang.System.getProperty('os.name').downcase)
  def windows? = os_name.include?('win')
  def mac? = os_name.include?('mac') || os_name.include?('darwin')
  def linux? = os_name.include?('nix') || os_name.include?('nux') || os_name.include?('aix')
else
  def windows? = Gem.win_platform?
  def mac? = RUBY_PLATFORM.match?(/darwin/)
  def linux? = RUBY_PLATFORM.match?(/linux/)
end

def ruby_command(code)
  @ruby_path ||=
    if windows?
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
  add_filter '/spec/' unless mri? && windows?
end

# Make sure to require your project AFTER starting SimpleCov
#
require 'process_executer'
