# frozen_string_literal: true

require 'logger'
require 'timeout'

require 'process_executer/destination_base'
require 'process_executer/destinations'
require 'process_executer/errors'
require 'process_executer/monitored_pipe'
require 'process_executer/options'
require 'process_executer/result'
require 'process_executer/result_with_capture'
require 'process_executer/runner'
require 'process_executer/runner_with_capture'

# The `ProcessExecuter` module provides methods to execute subprocess commands
# with enhanced features such as output capture, timeout handling, and custom
# environment variables.
#
# Methods:
#
# * {spawn_with_timeout}: a thin wrapper around `Process.spawn` that blocks until the
#   command finishes
# * {run}: Executes a command and returns the result including more flexible
#   redirection options, error handling, and logging.
#
# Features:
#
# * Supports executing commands via a shell or directly
# * Ability to redirect output to buffers or any object with a @write method
# * Optionally enforces timeouts and terminates long-running commands
# * Provides detailed status information, including the command that was run, the
#   options that were given, success, failure, or timeout states, and elapsed time
#
# @api public
module ProcessExecuter
  # Define shortcuts for SpawnWithTimeoutOptions
  SpawnWithTimeoutOptions = ProcessExecuter::Options::SpawnWithTimeoutOptions
  # Define shortcuts for RunOptions
  RunOptions = ProcessExecuter::Options::RunOptions
  # Define shortcuts for RunWithCaptureOptions
  RunWithCaptureOptions = ProcessExecuter::Options::RunWithCaptureOptions

  # Spawn a command, wait for it to finish, then return the result
  #
  # This command is a wrapper around Process.spawn and Process.waitpid2.
  #
  # A {ProcessExecuter::ArgumentError} will be raised if both options and
  # options_hash are given.
  #
  # A timeout may be specified with the :timeout_after option. The command will be
  # sent the SIGKILL signal if it does not end before the specified timeout.
  #
  # @overload spawn_with_timeout(*command, **options_hash)
  #
  #   @param command [Array<String>] see [Process modulem, Argument `command_line` or `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options_hash [Hash] In addition to the options documented in [Process module, Execution Options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options),
  #     the following options are supported: `:timeout_after`
  #
  #   @option options_hash [Numeric] :timeout_after the amount of time (in seconds) to
  #     wait before signaling the process with SIGKILL
  #
  # @overload spawn_with_timeout(*command, options)
  #
  #   @param command [Array<String>] see [Process modulem, Argument `command_line` or `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options [ProcessExecuter::Options::SpawnWithTimeoutOptions]
  #
  # @example command line given as a single string
  #   result = ProcessExecuter.spawn_with_timeout('echo "3\n2\n1" | sort')
  #   result.exited? # => true
  #   result.success? # => true
  #   result.exitstatus # => 0
  #   result.timed_out? # => false
  #
  # @example command given as an exe_path and args
  #   result = ProcessExecuter.spawn_with_timeout('ping', '-c', '1', 'localhost')
  #
  # @example with a timeout
  #   result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 0.01)
  #   result.exited? # => false
  #   result.success? # => nil
  #   result.signaled? # => true
  #   result.termsig # => 9
  #   result.timed_out? # => true
  #
  # @example with a env hash
  #   env = { 'EXITSTATUS' => '1' }
  #   result = ProcessExecuter.spawn_and_wait(env, 'exit $EXITSTATUS')
  #   result.success? # => false
  #   result.exitstatus # => 1
  #
  # @example capture stdout to a StringIO buffer
  #   stdout_buffer = StringIO.new
  #   stdout_pipe = ProcessExecuter::MonitoredPipe.new(stdout_buffer)
  #   begin
  #     result = ProcessExecuter.spawn_and_wait(env, 'echo "3\n2\n1" | sort', out: stdout_pipe)
  #     stdout_buffer.string # => "1\n2\n3\n"
  #   ensure
  #     stdout_pipe.close
  #   end
  #
  # @raise [ProcessExecuter::SpawnError] If Process.spawn raises an error before the command is run
  # @raise [ProcessExecuter::ArgumentError] If the command or an option is not valid
  #
  # @return [ProcessExecuter::Result]
  #
  # @api public
  #
  def self.spawn_with_timeout(*command, **options_hash)
    command, options = command_and_options(SpawnWithTimeoutOptions, command, options_hash)

    begin
      pid = Process.spawn(*command, **options.spawn_options)
    rescue StandardError => e
      raise ProcessExecuter::SpawnError, "Failed to spawn process: #{e.message}"
    end

    wait_for_process(pid, command, options)
  end

  # Wraps {spawn_with_timeout} adding more flexible redirection and other options
  #
  # This method wraps all option redirection destinations with a MonitoredPipe.
  # Normally an output redirection destination must be a pipe. When the destination
  # is wrapped by a MonitoredPipe, any object that implements #write can be given as
  # a output redirection destination (such as StringIO which normally isn't allowed).
  #
  # Accepts the same options as {spawn_with_timeout} and adds the following options:
  #
  # * `:raise_errors` to make execution errors an exception (default is `true`)
  # * `:logger` to log the command and its result at `:info` level.
  #
  # One of the following errors will be raised unless `raise_errors` is explicitly
  # set to `false`:
  #
  # * `ProcessExecuter::FailedError` if the command returns a non-zero
  #   exitstatus
  # * `ProcessExecuter::SignaledError` if the command exits because of
  #   an unhandled signal
  # * `ProcessExecuter::TimeoutError` if the command times out
  #
  # If `raise_errors` is false and there was an error, the returned Result object
  # indicate what the error .
  #
  # `ProcessExecuter::ProcessIOError` is raised if an exception is occurs while
  # collecting subprocess output. The `raise_errors` option is ignored in this case.
  #
  # If a `logger` is provided, it will be used to log:
  #
  # * The command that was executed and its status to `info` level
  # * The stdout and stderr output to `debug` level
  #
  # By default, Logger.new(nil) is used for the logger.
  #
  # It is an error to give both options and options_hash.
  #
  # @example capture stdout to a StringIO buffer
  #   out_buffer = StringIO.new
  #   result = ProcessExecuter.run('echo HELLO', out: out_buffer)
  #   out_buffer.string #=> "HELLO\n"
  #
  # @example with :raise_errors set to true
  #   begin
  #     result = ProcessExecuter.run('exit 1', raise_errors: true)
  #   rescue ProcessExecuter::FailedError => e
  #     e.result.exitstatus #=> 1
  #   end
  #
  # @example with :raise_errors set to false
  #   result = ProcessExecuter.run('exit 1', raise_errors: false)
  #   result.exitstatus #=> 1
  #
  # @example with a logger
  #   logger_buffer = StringIO.new
  #   logger = Logger.new(logger_buffer, level: :info)
  #   result = ProcessExecuter.run('echo HELLO', logger: logger)
  #   logger_buffer.string #=>
  #     "INFO -- : Running command: echo HELLO\nDEUBG -- : Command completed with exit status 0\n"
  #
  # @overload run(*command, **options_hash)
  #
  #   @param command [Array<String>] see [Process modulem, Argument `command_line` or `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param [Hash] options_hash in addition to the options supported by
  #     {spawn_with_timeout}, the following options may be given: `:raise_errors` and `:logger`
  #
  #   @option options_hash [Boolean] :raise_errors if true, an error will be raised if the command fails
  #
  #   @option options_hash [Logger] :logger a logger to use for logging the command and its result at the info level
  #
  #   @option options_hash [Numeric] :timeout_after the amount of time (in seconds) to
  #     wait before signaling the process with SIGKILL
  #
  # @overload run(*command, options)
  #
  #   @param command [Array<String>] see [Process modulem, Argument `command_line` or `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options [ProcessExecuter::Options::RunOptions]
  #
  # @raise [ProcessExecuter::SpawnError] If spawn raises an error before the command is run
  # @raise [ProcessExecuter::ArgumentError] If the command or an option is not valid
  # @raise [ProcessExecuter::FailedError] If the command runs and returns a non-zero exit code
  # @raise [ProcessExecuter::SignaledError] If the command runs and exits because of an uncaught signal
  # @raise [ProcessExecuter::TimeoutError] If the command runs and takes longer than the configured timeout_after
  # @raise [ProcessExecuter::ProcessIOError] If the command runs and the output can not be read
  #
  # @return [ProcessExecuter::Result]
  #
  # @api public
  #
  def self.run(*command, **options_hash)
    command, options = command_and_options(RunOptions, command, options_hash)
    ProcessExecuter::Runner.new.call(command, options)
  end

  # Wraps {run} and automatically captures stdout and stderr
  #
  # The captured output is accessed in the returned object's stdout and stderr
  # methods. Merged output (if the `merged_output: true` option is given) is
  # accessed in the stdout method.
  #
  # stdout and stderr redirection options may be given by the caller. This will
  # override the capture if given. This means that if an stdout redirection is given,
  # the result.stdout will be empty and if a stderr redirection is given, the
  # result.stderr will be empty. A `ProcessExecuter::ArgumentError` will be raised if
  # both a stderr redirection and the `merge_output: true` option are given.
  #
  # Accepts the same options as {run} and adds the following options:
  #
  # * `:merge_output` to merge stdout and stderr into a single capture buffer (default is false)
  #
  # A `ProcessExecuter::ArgumentError` will be raised if both an options object and
  # an options_hash are given.
  #
  # @example capture stdout and stderr
  #   result = ProcessExecuter.run_and_capture('echo HELLO; echo ERROR >&2')
  #   result.stdout #=> "HELLO\n"
  #   result.stderr #=> "ERROR\n"
  #
  # @example merge stdout and stderr
  #   result = ProcessExecuter.run_and_capture('echo HELLO; echo ERROR >&2', merge_output: true)
  #   # order of output is not guaranteed
  #   result.stdout #=> "HELLO\nERROR\n"
  #   result.stderr #=> ""
  #
  # @overload run_and_capture(*command, **options_hash)
  #
  #   @param command [Array<String>] see [Process modulem, Argument `command_line` or `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options_hash [Hash] in addition to the options supported by {run},
  #     `merge_output` may be given
  #
  #   @option options_hash [Boolean] :merge_output if true, stdout and stderr will be
  #     merged into a single capture buffer
  #
  # @overload run_and_capture(*command, options)
  #
  #   @param command [Array<String>] see [Process modulem, Argument `command_line` or `exe_path`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Argument+command_line)
  #     and [Process module, Argument `args`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Arguments+args)
  #
  #     If the first value is a Hash, it is treated as the environment hash. See
  #     [Process module, Execution Environment](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Environment).
  #
  #   @param options [ProcessExecuter::Options::RunAndCaptureOptions]
  #
  # @return [ProcessExecuter::ResultWithCapture]
  #
  # @api public
  #
  def self.run_with_capture(*command, **options_hash)
    command, options = command_and_options(RunWithCaptureOptions, command, options_hash)
    ProcessExecuter::RunnerWithCapture.new.call(command, options)
  end

  # Wait for process to terminate
  #
  # If a `:timeout_after` is specified in options, terminate the process after the
  # specified number of seconds.
  #
  # @param pid [Integer] the process ID
  # @param options [ProcessExecuter::Options] the options used
  #
  # @return [ProcessExecuter::Result] The result of the completed subprocess
  #
  # @api private
  #
  private_class_method def self.wait_for_process(pid, command, options)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    process_status, timed_out = wait_for_process_raw(pid, options.timeout_after)
    elapsed_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    ProcessExecuter::Result.new(process_status, command:, options:, timed_out:, elapsed_time:)
  end

  # Wait for a process to terminate returning the status and timed out flag
  #
  # @param pid [Integer] the process ID
  # @param timeout_after [Numeric, nil] the number of seconds to wait for the process to terminate
  # @return [Array<Process::Status, Boolean>] an array containing the process status and a boolean
  #   indicating whether the process timed out
  # @api private
  private_class_method def self.wait_for_process_raw(pid, timeout_after)
    timed_out = false

    process_status =
      begin
        Timeout.timeout(timeout_after) { Process.wait2(pid).last }
      rescue Timeout::Error
        Process.kill('KILL', pid)
        timed_out = true
        Process.wait2(pid).last
      end

    [process_status, timed_out]
  end

  # Takes a comamnd and options_hash to determine the options object
  #
  # To support either passing an options object or an options_hash, this method
  # takes a command and an options_hash and returns the command (with the trailing
  # options object removed if one is given) and and options object.
  #
  # @example options hash not empty
  #   SpawnWithTimeoutOptions = ProcessExecuter::Options::SpawnWithTimeoutOptions
  #   command = %w[echo hello]
  #   options_hash = { out: $stdout }
  #   command_out, options_out = ProcessExecuter.command_and_options(SpawnWithTimeoutOptions, command, options_hash)
  #   command_out #=> %w[echo hello]
  #   options_out #=> an options_class instance initialized with the options_hash
  #
  # @example option hash empty, command DOES NOT end with an options object
  #   SpawnWithTimeoutOptions = ProcessExecuter::Options::SpawnWithTimeoutOptions
  #   command = %w[echo hello]
  #   options_hash = {}
  #   command_out, options_out = ProcessExecuter.command_and_options(SpawnWithTimeoutOptions, command, options_hash)
  #   command_out #=> %w[echo hello]
  #   options_out #=> # options_class instance with all default values is returned
  #
  # @example options_hash empty, command ends with an options object
  #   SpawnWithTimeoutOptions = ProcessExecuter::Options::SpawnWithTimeoutOptions
  #   options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(out: $stdout)
  #   command = ['echo', 'hello', options]
  #   options_hash = {}
  #   command_out, options_out = ProcessExecuter.spawn_and_wait_options(command, options_hash)
  #   command_out #=> %w[echo hello] # options removed from command
  #   options_out #=> what was previously command[-1]
  #
  # @param options_class [Class] the class of the options object
  #
  # @param command [Array] the command to be executed (possibly with an instance of
  #   options_class at the end)
  #
  # @param options_hash [Hash] the (possibly empty) hash of options
  #
  # @return [Array, options_class] the command (possible with the options
  #   removed) and an instance of options_class
  #
  # @api private
  #
  private_class_method def self.command_and_options(options_class, command, options_hash)
    if !options_hash.empty?
      [command, options_class.new(**options_hash)]
    elsif command[-1].is_a?(options_class)
      [command[..-2], command[-1]]
    else
      [command, options_class.new]
    end
  end
end
