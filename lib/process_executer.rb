# frozen_string_literal: true

require 'logger'
require 'timeout'

require 'process_executer/destination_base'
require 'process_executer/destinations'
require 'process_executer/errors'
require 'process_executer/monitored_pipe'
require 'process_executer/options'
require 'process_executer/result'
require 'process_executer/runner'

# The `ProcessExecuter` module provides methods to execute subprocess commands
# with enhanced features such as output capture, timeout handling, and custom
# environment variables.
#
# Methods:
#
# * {run}: Executes a command and returns the result which includes the process
#   status and output
# * {spawn_and_wait}: a thin wrapper around `Process.spawn` that blocks until the
#   command finishes
#
# Features:
#
# * Supports executing commands via a shell or directly.
# * Captures stdout and stderr to buffers, files, or custom objects.
# * Optionally enforces timeouts and terminates long-running commands.
# * Provides detailed status information, including the command that was run, the
#   options that were given, and success, failure, or timeout states.
#
# @api public
module ProcessExecuter
  # Run a command in a subprocess, wait for it to finish, then return the result
  #
  # This method is a thin wrapper around
  # [Process.spawn](https://docs.ruby-lang.org/en/3.3/Process.html#method-c-spawn)
  # and blocks until the command terminates.
  #
  # A timeout may be specified with the `:timeout_after` option. The command will be
  # sent the SIGKILL signal if it does not terminate within the specified timeout.
  #
  # @example
  #   result = ProcessExecuter.spawn_and_wait('echo hello')
  #   result.exited? # => true
  #   result.success? # => true
  #   result.timed_out? # => false
  #
  # @example with a timeout
  #   result = ProcessExecuter.spawn_and_wait('sleep 10', timeout_after: 0.01)
  #   result.exited? # => false
  #   result.success? # => nil
  #   result.signaled? # => true
  #   result.termsig # => 9
  #   result.timed_out? # => true
  #
  # @example capturing stdout to a string
  #   stdout_buffer = StringIO.new
  #   stdout_pipe = ProcessExecuter::MonitoredPipe.new(stdout_buffer)
  #   result = ProcessExecuter.spawn_and_wait('echo hello', out: stdout_pipe)
  #   stdout_buffer.string # => "hello\n"
  #
  # @see https://ruby-doc.org/core-3.1.2/Kernel.html#method-i-spawn Kernel.spawn
  #   documentation for valid command and options
  #
  # @see ProcessExecuter::Options#initialize ProcessExecuter::Options#initialize for
  #   options that may be specified
  #
  # @param command [Array<String>] The command to execute
  # @param options_hash [Hash] The options to use when executing the command
  #
  # @return [ProcessExecuter::Result] The result of the completed subprocess
  #
  def self.spawn_and_wait(*command, **options_hash)
    options = ProcessExecuter.spawn_and_wait_options(options_hash)
    spawn_and_wait_with_options(command, options)
  end

  # Run a command in a subprocess, wait for it to finish, then return the result
  #
  # @see ProcessExecuter.spawn_and_wait for full documentation
  #
  # @param command [Array<String>] The command to run
  # @param options [ProcessExecuter::Options::SpawnAndWaitOptions] The options to use when running the command
  #
  # @return [ProcessExecuter::Result] The result of the completed subprocess
  # @api private
  def self.spawn_and_wait_with_options(command, options)
    pid = Process.spawn(*command, **options.spawn_options)
    wait_for_process(pid, command, options)
  end

  # Execute the given command as a subprocess blocking until it finishes
  #
  # Works just like {ProcessExecuter.spawn}, but does the following in addition:
  #
  #   1. If nothing is specified for `out`, stdout is captured to a `StringIO` object
  #      which can be accessed via the Result object in `result.options.out`. The
  #      same applies to `err`.
  #
  #   2. `out` and `err` are automatically wrapped in a
  #      `ProcessExecuter::MonitoredPipe` object so that any object that implements
  #      `#write` (or an Array of such objects) can be given for `out` and `err`.
  #
  #   3. Raises one of the following errors unless `raise_errors` is explicitly set
  #      to `false`:
  #
  #      * `ProcessExecuter::FailedError` if the command returns a non-zero
  #        exitstatus
  #      * `ProcessExecuter::SignaledError` if the command exits because of
  #        an unhandled signal
  #      * `ProcessExecuter::TimeoutError` if the command times out
  #
  #      If `raise_errors` is false, the returned Result object will contain the error.
  #
  #   4. Raises a `ProcessExecuter::ProcessIOError` if an exception is raised
  #      while collecting subprocess output. This can not be turned off.
  #
  #   5. If a `logger` is provided, it will be used to log:
  #
  #      * The command that was executed and its status to `info` level
  #      * The stdout and stderr output to `debug` level
  #
  #     By default, Logger.new(nil) is used for the logger.
  #
  # This method takes two forms:
  #
  # 1. The command is executed via a shell when the command is given as a single
  #    string:
  #
  #     `ProcessExecuter.run([env, ] command_line, options = {}) ->` {ProcessExecuter::Result}
  #
  # 2. The command is executed directly (bypassing the shell) when the command and it
  #    arguments are given as an array of strings:
  #
  #     `ProcessExecuter.run([env, ] exe_path, *args, options = {}) ->` {ProcessExecuter::Result}
  #
  # Optional argument `env` is a hash that affects ENV for the new process; see
  # [Execution
  # Environment](https://docs.ruby-lang.org/en/3.3/Process.html#module-Process-label-Execution+Environment).
  #
  # Argument `options` is a hash of options for the new process. See the options listed below.
  #
  # @example Run a command given as a single string (uses shell)
  #   # The command must be properly shell escaped when passed as a single string.
  #   command = 'echo "stdout: `pwd`" && echo "stderr: $HOME" 1>&2'
  #   result = ProcessExecuter.run(command)
  #   result.success? #=> true
  #   result.stdout #=> "stdout: /Users/james/projects/main-branch/process_executer\n"
  #   result.stderr #=> "stderr: /Users/james\n"
  #
  # @example Run a command given as an array of strings (does not use shell)
  #   # The command and its args must be provided as separate strings in the array.
  #   # Shell expansions and redirections are not supported.
  #   command = ['git', 'clone', 'https://github.com/main-branch/process_executer']
  #   result = ProcessExecuter.run(*command)
  #   result.success? #=> true
  #   result.stdout #=> ""
  #   result.stderr #=> "Cloning into 'process_executer'...\n"
  #
  # @example Run a command with a timeout
  #   command = ['sleep', '1']
  #   result = ProcessExecuter.run(*command, timeout_after: 0.01)
  #   #=> raises ProcessExecuter::TimeoutError which contains the command result
  #
  # @example Run a command which fails
  #   command = ['exit 1']
  #   result = ProcessExecuter.run(*command)
  #   #=> raises ProcessExecuter::FailedError which contains the command result
  #
  # @example Run a command which exits due to an unhandled signal
  #   command = ['kill -9 $$']
  #   result = ProcessExecuter.run(*command)
  #   #=> raises ProcessExecuter::SignaledError which contains the command result
  #
  # @example Do not raise an error when the command fails
  #   command = ['echo "Some error" 1>&2 && exit 1']
  #   result = ProcessExecuter.run(*command, raise_errors: false)
  #   result.success? #=> false
  #   result.exitstatus #=> 1
  #   result.stdout #=> ""
  #   result.stderr #=> "Some error\n"
  #
  # @example Set environment variables
  #   env = { 'FOO' => 'foo', 'BAR' => 'bar' }
  #   command = 'echo "$FOO$BAR"'
  #   result = ProcessExecuter.run(env, *command)
  #   result.stdout #=> "foobar\n"
  #
  # @example Set environment variables when using a command array
  #   env = { 'FOO' => 'foo', 'BAR' => 'bar' }
  #   command = ['ruby', '-e', 'puts ENV["FOO"] + ENV["BAR"]']
  #   result = ProcessExecuter.run(env, *command)
  #   result.stdout #=> "foobar\n"
  #
  # @example Unset environment variables
  #   env = { 'FOO' => nil } # setting to nil unsets the variable in the environment
  #   command = ['echo "FOO: $FOO"']
  #   result = ProcessExecuter.run(env, *command)
  #   result.stdout #=> "FOO: \n"
  #
  # @example Reset existing environment variables and add new ones
  #   env = { 'PATH' => '/bin' }
  #   result = ProcessExecuter.run(env, 'echo "Home: $HOME" && echo "Path: $PATH"', unsetenv_others: true)
  #   result.stdout #=> "Home: \n/Path: /bin\n"
  #
  # @example Run command in a different directory
  #   command = ['pwd']
  #   result = ProcessExecuter.run(*command, chdir: '/tmp')
  #   result.stdout #=> "/tmp\n"
  #
  # @example Capture stdout and stderr into a single buffer
  #   command = ['echo "stdout" && echo "stderr" 1>&2']
  #   result = ProcessExecuter.run(*command, [out:, err:]: StringIO.new)
  #   result.stdout #=> "stdout\nstderr\n"
  #   result.stderr #=> "stdout\nstderr\n"
  #   result.stdout.object_id == result.stderr.object_id #=> true
  #
  # @example Capture to an explicit buffer
  #   out = StringIO.new
  #   err = StringIO.new
  #   command = ['echo "stdout" && echo "stderr" 1>&2']
  #   result = ProcessExecuter.run(*command, out: out, err: err)
  #   out.string #=> "stdout\n"
  #   err.string #=> "stderr\n"
  #
  # @example Capture to a file
  #   # Same technique can be used for stderr
  #   out = File.open('stdout.txt', 'w')
  #   err = StringIO.new
  #   command = ['echo "stdout" && echo "stderr" 1>&2']
  #   result = ProcessExecuter.run(*command, out: out, err: err)
  #   out.close
  #   File.read('stdout.txt') #=> "stdout\n"
  #   # stderr is still captured to a StringIO buffer internally
  #   result.stderr #=> "stderr\n"
  #
  # @example Capture to multiple destinations (e.g. files, buffers, STDOUT, etc.)
  #   # Same technique can be used for stderr
  #   out_buffer = StringIO.new
  #   out_file = File.open('stdout.txt', 'w')
  #   command = ['echo "stdout" && echo "stderr" 1>&2']
  #   result = ProcessExecuter.run(*command, out: [:tee, out_buffer, out_file])
  #   # You must manage closing resources you create yourself
  #   out_file.close
  #   out_buffer.string #=> "stdout\n"
  #   File.read('stdout.txt') #=> "stdout\n"
  #   result.stdout #=> "stdout\n"
  #
  # @param command [Array<String>] The command to run
  #
  #   If the first element of command is a Hash, it is added to the ENV of
  #   the new process. See [Execution Environment](https://ruby-doc.org/3.3.6/Process.html#module-Process-label-Execution+Environment)
  #   for more details. The env hash is then removed from the command array.
  #
  #   If the first and only (remaining) command element is a string, it is passed to
  #   a subshell if it begins with a shell reserved word, contains special built-ins,
  #   or includes shell metacharacters.
  #
  #   Care must be taken to properly escape shell metacharacters in the command string.
  #
  #   Otherwise, the command is run bypassing the shell. When bypassing the shell, shell expansions
  #   and redirections are not supported.
  #
  # @param options_hash [Hash] Additional options
  # @option options_hash [Numeric] :timeout_after The maximum seconds to wait for the
  #   command to complete
  #
  #     If zero or nil, the command will not time out. If the command
  #     times out, it is killed via a SIGKILL signal. A {ProcessExecuter::TimeoutError}
  #     will be raised if the `:raise_errors` option is true.
  #
  #     If the command does not exit when receiving the SIGKILL signal, this method may hang indefinitely.
  #
  # @option options_hash [#write] :out (nil) The object to write stdout to
  # @option options_hash [#write] :err (nil) The object to write stderr to
  # @option options_hash [Boolean] :raise_errors (true) Raise an exception if the command fails
  # @option options_hash [Boolean] :unsetenv_others (false) If true, unset all environment variables before
  #   applying the new ones
  # @option options_hash [true, Integer, nil] :pgroup (nil) true or 0: new process group; non-zero: join
  #   the group, nil: existing group
  # @option options_hash [Boolean] :new_pgroup (nil) Create a new process group (Windows only)
  # @option options_hash [Integer] :rlimit_resource_name (nil) Set resource limits (see Process.setrlimit)
  # @option options_hash [Integer] :umask (nil) Set the umask (see File.umask)
  # @option options_hash [Boolean] :close_others (false) If true, close non-standard file descriptors
  # @option options_hash [String] :chdir (nil) The directory to run the command in
  # @option options_hash [Logger] :logger The logger to use
  #
  # @raise [ProcessExecuter::FailedError] if the command returned a non-zero exit status
  # @raise [ProcessExecuter::SignaledError] if the command exited because of an unhandled signal
  # @raise [ProcessExecuter::TimeoutError] if the command timed out
  # @raise [ProcessExecuter::ProcessIOError] if an exception was raised while collecting subprocess output
  #
  # @return [ProcessExecuter::Result] The result of the completed subprocess
  #
  def self.run(*command, **options_hash)
    options = ProcessExecuter.run_options(options_hash)
    run_with_options(command, options)
  end

  # Run a command with the given options
  #
  # @see ProcessExecuter.run for full documentation
  #
  # @param command [Array<String>] The command to run
  # @param options [ProcessExecuter::Options::RunOptions] The options to use when running the command
  #
  # @return [ProcessExecuter::Result] The result of the completed subprocess
  #
  # @api private
  def self.run_with_options(command, options)
    ProcessExecuter::Runner.new.call(command, options)
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

  # Convert a hash to a SpawnOptions object
  #
  # @example
  #   options_hash = { out: $stdout }
  #   options = ProcessExecuter.spawn_options(options_hash) # =>
  #     #<ProcessExecuter::Options::SpawnOptions:0x00007f8f9b0b3d20 out: $stdout>
  #   ProcessExecuter.spawn_options(options) # =>
  #     #<ProcessExecuter::Options::SpawnOptions:0x00007f8f9b0b3d20 out: $stdout>
  #
  # @param obj [Hash, SpawnOptions] the object to be converted
  #
  # @return [SpawnOptions]
  #
  # @raise [ArgumentError] if obj is not a Hash or SpawnOptions
  #
  # @api public
  #
  def self.spawn_options(obj)
    case obj
    when ProcessExecuter::Options::SpawnOptions
      obj
    when Hash
      ProcessExecuter::Options::SpawnOptions.new(**obj)
    else
      raise ArgumentError, "Expected a Hash or ProcessExecuter::Options::SpawnOptions but got a #{obj.class}"
    end
  end

  # Convert a hash to a SpawnAndWaitOptions object
  #
  # @example
  #   options_hash = { out: $stdout }
  #   options = ProcessExecuter.spawn_and_wait_options(options_hash) # =>
  #     #<ProcessExecuter::Options::SpawnAndWaitOptions:0x00007f8f9b0b3d20 out: $stdout>
  #   ProcessExecuter.spawn_and_wait_options(options) # =>
  #     #<ProcessExecuter::Options::SpawnAndWaitOptions:0x00007f8f9b0b3d20 out: $stdout>
  #
  # @param obj [Hash, SpawnAndWaitOptions] the object to be converted
  #
  # @return [SpawnAndWaitOptions]
  #
  # @raise [ArgumentError] if obj is not a Hash or SpawnOptions
  #
  # @api public
  #
  def self.spawn_and_wait_options(obj)
    case obj
    when ProcessExecuter::Options::SpawnAndWaitOptions
      obj
    when Hash
      ProcessExecuter::Options::SpawnAndWaitOptions.new(**obj)
    else
      raise ArgumentError, "Expected a Hash or ProcessExecuter::Options::SpawnAndWaitOptions but got a #{obj.class}"
    end
  end

  # Convert a hash to a RunOptions object
  #
  # @example
  #   options_hash = { out: $stdout }
  #   options = ProcessExecuter.run_options(options_hash) # =>
  #     #<ProcessExecuter::Options::RunOptions:0x00007f8f9b0b3d20 out: $stdout>
  #   ProcessExecuter.run_options(options) # =>
  #     #<ProcessExecuter::Options::RunOptions:0x00007f8f9b0b3d20 out: $stdout>
  #
  # @param obj [Hash, RunOptions] the object to be converted
  #
  # @return [RunOptions]
  #
  # @raise [ArgumentError] if obj is not a Hash or SpawnOptions
  #
  # @api public
  #
  def self.run_options(obj)
    case obj
    when ProcessExecuter::Options::RunOptions
      obj
    when Hash
      ProcessExecuter::Options::RunOptions.new(**obj)
    else
      raise ArgumentError, "Expected a Hash or ProcessExecuter::Options::RunOptions but got a #{obj.class}"
    end
  end
end
