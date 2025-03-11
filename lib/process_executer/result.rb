# frozen_string_literal: true

require 'delegate'

module ProcessExecuter
  # A decorator for Process::Status that adds the following attributes:
  #
  # * `command`: the command that was used to spawn the process
  # * `options`: the options that were used to spawn the process
  # * `elapsed_time`: the secs the command ran
  # * `stdout`: the captured stdout output
  # * `stderr`: the captured stderr output
  # * `timed_out?`: true if the process timed out
  #
  # @api public
  #
  class Result < SimpleDelegator
    # Create a new Result object
    #
    # @param status [Process::Status] the status to delegate to
    # @param command [Array] the command that was used to spawn the process
    # @param options [ProcessExecuter::Options] the options that were used to spawn the process
    # @param timed_out [Boolean] true if the process timed out
    # @param elapsed_time [Numeric] the secs the command ran
    #
    # @example
    #   command = ['sleep 1']
    #   options = ProcessExecuter::Options.new(timeout_after: 0.5)
    #   start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    #   timed_out = false
    #   status = nil
    #   pid = Process.spawn(*command, **options.spawn_options)
    #   Timeout.timeout(options.timeout_after) do
    #     _pid, status = Process.wait2(pid)
    #   rescue Timeout::Error
    #     Process.kill('KILL', pid)
    #     timed_out = true
    #     _pid, status = Process.wait2(pid)
    #   end
    #   elapsed_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    #
    #   ProcessExecuter::Result.new(status, command:, options:, timed_out:, elapsed_time:)
    #
    # @api public
    #
    def initialize(status, command:, options:, timed_out:, elapsed_time:)
      super(status)
      @command = command
      @options = options
      @timed_out = timed_out
      @elapsed_time = elapsed_time
    end

    # The command that was used to spawn the process
    # @see Process.spawn
    # @example
    #   result.command #=> [{ 'GIT_DIR' => '/path/to/repo' }, 'git', 'status']
    # @return [Array]
    attr_reader :command

    # The options that were used to spawn the process
    # @see Process.spawn
    # @example
    #   result.options #=> { chdir: '/path/to/repo', timeout_after: 0.5 }
    # @return [Hash]
    # @api public
    attr_reader :options

    # The secs the command ran
    # @example
    #   result.elapsed_time #=> 10
    # @return [Numeric, nil]
    # @api public
    attr_reader :elapsed_time

    # @!attribute [r] timed_out?
    # True if the process timed out and was sent the SIGKILL signal
    # @example
    #   result = ProcessExecuter.spawn('sleep 10', timeout_after: 0.01)
    #   result.timed_out? # => true
    # @return [Boolean]
    #
    def timed_out?
      @timed_out
    end

    # Overrides the default success? method to return nil if the process timed out
    #
    # This is because when a timeout occurs, Windows will still return true.
    #
    # @example
    #   result = ProcessExecuter.spawn('sleep 10', timeout_after: 0.01)
    #   result.success? # => nil
    # @return [true, nil]
    #
    def success?
      return nil if timed_out? # rubocop:disable Style/ReturnNilInPredicateMethodDefinition

      super
    end

    # Return a string representation of the result
    # @example
    #   result.to_s #=> "pid 70144 SIGKILL (signal 9) timed out after 10s"
    # @return [String]
    def to_s
      "#{super}#{timed_out? ? " timed out after #{options.timeout_after}s" : ''}"
    end

    # Return the captured stdout output
    #
    # This output is only returned if the `:out` option value is a
    # `ProcessExecuter::MonitoredPipe`.
    #
    # @example
    #   # Note that `ProcessExecuter.run` will wrap the given out: object in a
    #   # ProcessExecuter::MonitoredPipe
    #   result = ProcessExecuter.run('echo hello': out: StringIO.new)
    #   result.stdout #=> "hello\n"
    #
    # @return [String, nil]
    #
    def stdout
      pipe = options.stdout_redirection_value
      return nil unless pipe.is_a?(ProcessExecuter::MonitoredPipe)

      pipe.destination.string
    end

    # Return the captured stderr output
    #
    # This output is only returned if the `:err` option value is a
    # `ProcessExecuter::MonitoredPipe`.
    #
    # @example
    #   # Note that `ProcessExecuter.run` will wrap the given err: object in a
    #   # ProcessExecuter::MonitoredPipe
    #   result = ProcessExecuter.run('echo ERROR 1>&2', err: StringIO.new)
    #   resuilt.stderr #=> "ERROR\n"
    #
    # @return [String, nil]
    #
    def stderr
      pipe = options.stderr_redirection_value
      return nil unless pipe.is_a?(ProcessExecuter::MonitoredPipe)

      pipe.destination.string
    end
  end
end
