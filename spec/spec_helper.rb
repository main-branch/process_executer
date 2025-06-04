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

RSpec.shared_examples 'a valid option value was given' do |option, encoding|
  let(:option) { option }
  let(:encoding) { encoding }
  let(:options_hash) { { option => encoding } }
  it "should set options.#{option} to #{encoding.inspect}" do
    expect(subject.send(option)).to eq(encoding)
  end
end

RSpec.shared_examples 'an invalid option value was given' do |option, encoding, message|
  let(:option) { option }
  let(:encoding) { encoding }
  let(:options_hash) { { option => encoding } }

  it "should raise a ProcessExecuter::ArgumentError for #{encoding.inspect}" do
    expect { subject }.to(
      raise_error(
        ProcessExecuter::ArgumentError,
        message
      )
    )
  end
end

RSpec.shared_examples 'a Boolean option' do |option|
  value = true
  context "when given { #{option}: #{value} }" do
    it_behaves_like 'a valid option value was given', option, value
  end

  value = false
  context "when given { #{option}: #{value} }" do
    it_behaves_like 'a valid option value was given', option, value
  end

  value = 'non_boolean_value'
  context "when given { #{option}: #{value.inspect} }" do
    it_behaves_like(
      'an invalid option value was given', option, value,
      "#{option} must be true or false but was #{value.inspect}"
    )
  end
end

RSpec.shared_examples 'an encoding option' do |option, default:|
  encoding = nil
  context "when given { #{option}: #{encoding.inspect} }" do
    it_behaves_like 'a valid option value was given', option, encoding
  end

  context "when given { #{option}: <Encoding object> }" do
    encoding = Encoding::UTF_8
    context "when given { #{option}: #{encoding.inspect} }" do
      it_behaves_like 'a valid option value was given', option, encoding
    end
  end

  context "when given { #{option}: <String> }" do
    encoding = 'UTF-8'
    context "when given { #{option}: #{encoding.inspect} }" do
      it_behaves_like 'a valid option value was given', option, encoding
    end

    encoding = 'invalid_encoding_name'
    context "when given { #{option}: #{encoding.inspect} }" do
      it_behaves_like(
        'an invalid option value was given', option, encoding,
        %(#{option} specifies an unknown encoding name: "#{encoding}")
      )
    end
  end

  context "when given { #{option}: <Symbol> }" do
    encoding = :binary
    context "when given { #{option}: #{encoding.inspect} }" do
      it_behaves_like 'a valid option value was given', option, encoding
    end

    encoding = :default_external
    context "when given { #{option}: #{encoding.inspect} }" do
      it_behaves_like 'a valid option value was given', option, encoding
    end

    encoding = :invalid_encoding_symbol
    context "when given { #{option}: #{encoding.inspect} }" do
      it_behaves_like(
        'an invalid option value was given', option, encoding,
        "#{option} when given as a symbol must be :binary or :default_external, " \
        "but was #{encoding.inspect}"
      )
    end
  end

  context "when given { #{option}: <Invalid encoding type> }" do
    encoding = 1 # Integers are not a valid encoding type
    context "when given { #{option}: #{encoding.inspect} }" do
      it_behaves_like(
        'an invalid option value was given', option, encoding,
        "#{option} must be an Encoding object, String, " \
        "Symbol (:binary, :default_external), or nil, but was #{encoding.inspect}"
      )
    end
  end

  context "when the #{option} option is not given" do
    it "should set options.#{option} to the default value #{default.inspect}" do
      expect(subject.send(option)).to eq(default)
    end
  end
end

RSpec.shared_examples 'a logger option' do |option|
  logger = nil
  context "when given { #{option}: #{logger.inspect} }" do
    it_behaves_like(
      'an invalid option value was given', option, logger,
      "#{option} must respond to #info and #debug but was #{logger.inspect}"
    )
  end

  logger = Logger.new(nil)
  context "when given { #{option}: #{logger.inspect} }" do
    it_behaves_like 'a valid option value was given', option, logger
  end

  logger = 'non_logger_object'
  context "when given { #{option}: #{logger.inspect} }" do
    it_behaves_like(
      'an invalid option value was given', option, logger,
      "#{option} must respond to #info and #debug but was #{logger.inspect}"
    )
  end
end

RSpec.shared_examples 'a timeout option' do |option|
  timeout_after = nil
  context "when given { #{option}: #{timeout_after.inspect} }" do
    it_behaves_like 'a valid option value was given', option, timeout_after
  end

  timeout_after = 10
  context "when given { #{option}: #{timeout_after.inspect} }" do
    it_behaves_like 'a valid option value was given', option, timeout_after
  end

  timeout_after = 1.5
  context "when given { #{option}: #{timeout_after.inspect} }" do
    it_behaves_like 'a valid option value was given', option, timeout_after
  end

  timeout_after = 0
  context "when given { #{option}: #{timeout_after.inspect} }" do
    it_behaves_like 'a valid option value was given', option, timeout_after
  end

  timeout_after = -1
  context "when given { #{option}: #{timeout_after.inspect} }" do
    it_behaves_like(
      'an invalid option value was given', option, timeout_after,
      "#{option} must be nil or a non-negative real number but was #{timeout_after.inspect}"
    )
  end

  timeout_after = 'non_numeric_object'
  context "when given { #{option}: #{timeout_after.inspect} }" do
    it_behaves_like(
      'an invalid option value was given', option, timeout_after,
      "#{option} must be nil or a non-negative real number but was #{timeout_after.inspect}"
    )
  end
end

# @example
#   describe 'ProcessExecuter::Options::RunOptions' do
#     non_spawn_options = {    other_options = {
#       logger: Logger.new(StringIO.new),
#       raise_errors: false
#     }
#     it_behaves_like 'it returns only Process.spawn options', **non_spawn_options
#
RSpec.shared_examples 'it returns only Process.spawn options' do |**non_spawn_options|
  spawn_options = {
    unsetenv_others: true,
    pgroup: 900,
    new_pgroup: true,
    rlimit_resourcename: [1, 2],
    umask: 0o644,
    close_others: true,
    chdir: '/tmp',
    out: '/dev/null',
    err: '/dev/null',
    in: '/dev/null',
    0 => '/dev/null',
    1 => '/dev/null',
    2 => '/dev/null',
    $stdout => '/dev/null',
    [1, 2] => '/dev/null',
    [$stdout, $stderr] => '/dev/null'
  }

  let(:spawn_options) { spawn_options }

  subject { described_class.new(**spawn_options, **non_spawn_options).spawn_options }

  it { is_expected.to eq(spawn_options) }
end

require 'rbconfig'

SimpleCov::RSpec.start(list_uncovered_lines: ci_build?) do
  # Avoid false positives in spec directory from JRuby, TruffleRuby, and Windows
  add_filter '/spec/' unless mri? && windows?
end

# Make sure to require your project AFTER starting SimpleCov
#
require 'process_executer'
