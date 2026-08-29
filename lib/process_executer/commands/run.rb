# frozen_string_literal: true

require 'English'

require_relative '../errors'
require_relative 'spawn_with_timeout'

module ProcessExecuter
  module Commands
    # Run a command and return the {ProcessExecuter::Result}
    #
    # Extends {ProcessExecuter::Commands::SpawnWithTimeout} to provide the core functionality for
    # {ProcessExecuter.run}.
    #
    # It accepts all [Process.spawn execution
    # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options)
    # plus the additional options `timeout_after`, `raise_errors` and `logger`.
    #
    # This class wraps any stdout or stderr redirection destinations in a {MonitoredPipe}.
    # This allows any class that implements `#write` to be used as an output redirection
    # destination. This means that you can redirect to a StringIO which is not possible
    # with `Process.spawn`.
    #
    # The wrapper pipes are kept in an internal hash that is combined with the
    # user's options only when `Process.spawn` is called. The options object the
    # caller gave is never modified, so it can be reused for another run and
    # `result.options` returns the destinations as the user configured them.
    #
    # @api private
    #
    class Run < SpawnWithTimeout
      # Create a new Run instance
      #
      # @example
      #   options = ProcessExecuter::Options::RunOptions.new(raise_errors: true)
      #   result = ProcessExecuter::Commands::Run.new('echo hello', options).call
      #   result.success? # => true
      #
      # @param command [Array<String>] The command to run in the subprocess
      # @param options [ProcessExecuter::Options::RunOptions] The options to use when running the command
      #
      def initialize(command, options)
        super
        @redirection_overrides = {}
      end

      # Run a command and return the result
      #
      # Wrap the stdout and stderr redirection destinations in pipes and then execute
      # the command.
      #
      # @example
      #   options = ProcessExecuter::Options::RunOptions.new(raise_errors: true)
      #   result = ProcessExecuter::Commands::Run.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
      #
      # @raise [ProcessExecuter::SpawnError] `Process.spawn` raised an error before the
      #   command was run
      #
      # @raise [ProcessExecuter::FailedError] If the command ran and failed
      #
      # @raise [ProcessExecuter::SignaledError] If the command ran and terminated due to
      #   an unhandled signal
      #
      # @raise [ProcessExecuter::TimeoutError] If the command timed out
      #
      # @raise [ProcessExecuter::ProcessIOError] If there was an exception while
      #   collecting subprocess output, or the output was truncated because it
      #   could not be fully collected before the close timeout
      #
      # @return [ProcessExecuter::Result] The result of the completed subprocess
      #
      def call
        opened_pipes = {}
        wrap_stdout_stderr(opened_pipes)
        super.tap do
          log_result
          raise_errors if options.raise_errors
        end
      ensure
        close_pipes_and_check_errors(opened_pipes, $ERROR_INFO)
      end

      private

      # Redirection options to apply on top of the user's options at spawn time
      #
      # Holds the {MonitoredPipe} wrappers created by {#wrap_stdout_stderr} (and
      # the capture redirections added by subclasses) keyed by the redirection
      # option key. Keeping them here instead of writing them into {#options}
      # leaves the caller's options object unmodified.
      #
      # @return [Hash<Object, Object>]
      #
      attr_reader :redirection_overrides

      # The options to pass to Process.spawn
      #
      # The user's spawn options with the redirection destinations replaced by
      # their internal {MonitoredPipe} wrappers.
      #
      # @return [Hash]
      #
      def spawn_options = super.merge(redirection_overrides)

      # Wrap the stdout and stderr redirection options with a MonitoredPipe
      #
      # The wrapper pipes are recorded in {#redirection_overrides} instead of
      # being written into {#options} so the caller's options object is not
      # modified.
      #
      # Each pipe is added to `opened_pipes` as soon as it is created so that,
      # if creating a later pipe raises, the caller's ensure block can close the
      # pipes created so far.
      #
      # @param opened_pipes [Hash<Object, ProcessExecuter::MonitoredPipe>] an
      #   accumulator for the opened pipes (the Object is the option key)
      #
      # @return [Hash<Object, ProcessExecuter::MonitoredPipe>] the given `opened_pipes`
      #
      def wrap_stdout_stderr(opened_pipes)
        effective_redirections.each do |key, value|
          next unless should_wrap?(key, value)

          wrapped_destination = ProcessExecuter::MonitoredPipe.new(value)
          opened_pipes[key] = wrapped_destination
          redirection_overrides[key] = wrapped_destination
        end
        opened_pipes
      end

      # The options as given by the user with {#redirection_overrides} applied
      #
      # @return [Hash<Object, Object>]
      #
      def effective_redirections = options.to_h.merge(redirection_overrides)

      # Close the given pipes and raise any pipe error unless already unwinding
      #
      # When `in_flight_error` is set, `#call` is unwinding from an exception
      # and that exception (not a pipe destination error or a pipe cleanup
      # error) must be the one the caller sees, so nothing is raised here.
      #
      # @param opened_pipes [Hash<Object, ProcessExecuter::MonitoredPipe>] the pipes to close
      #
      # @param in_flight_error [Exception, nil] the exception `#call` is unwinding from, if any
      #
      # @raise [ProcessExecuter::ProcessIOError] if a pipe recorded a destination
      #   exception or gave up draining before reaching EOF (truncated output)
      #
      # @raise [StandardError] the first error raised while closing the pipes
      #
      # @return [void]
      #
      def close_pipes_and_check_errors(opened_pipes, in_flight_error)
        close_error = close_pipes(opened_pipes)
        return if in_flight_error

        opened_pipes.each do |option_key, pipe|
          raise_pipe_error(option_key, pipe)
          raise_truncation_error(option_key, pipe)
        end
        raise close_error if close_error
      end

      # Close the given pipes, continuing if closing one of them raises
      #
      # Closing continues past a failure so that one pipe's error does not leak
      # the monitoring threads and file descriptors of the pipes after it.
      #
      # All pipes share a single close deadline so that this method -- called
      # from `#call`'s ensure block -- returns in bounded time even when a
      # process outside this object's control (such as an orphaned descendant
      # of a timed out command) still holds a pipe's write fd open. A pipe
      # whose drain is cut short by the deadline records it via
      # {MonitoredPipe#truncated?}.
      #
      # @param opened_pipes [Hash<Object, ProcessExecuter::MonitoredPipe>] the pipes to close
      #
      # @return [StandardError, nil] the first error raised while closing, or nil if none was raised
      #
      def close_pipes(opened_pipes)
        first_close_error = nil
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MonitoredPipe::DEFAULT_CLOSE_TIMEOUT
        opened_pipes.each_value do |pipe|
          remaining_time = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          pipe.close(timeout: [remaining_time, 0].max)
        rescue StandardError => e
          first_close_error ||= e
        end
        first_close_error
      end

      # Should the redirection option be wrapped by a MonitoredPipe
      # @param key [Object] The option key
      # @param value [Object] The option value
      # @return [Boolean] Whether the option should be wrapped
      def should_wrap?(key, value)
        (options.stdout_redirection?(key) || options.stderr_redirection?(key)) &&
          ProcessExecuter::Destinations.compatible_with_monitored_pipe?(value)
      end

      # Raise an error if the command failed
      # @return [void]
      # @raise [ProcessExecuter::FailedError] If the command ran and failed
      # @raise [ProcessExecuter::SignaledError] If the command ran and terminated due to an unhandled signal
      # @raise [ProcessExecuter::TimeoutError] If the command timed out
      def raise_errors
        raise TimeoutError, result if result.timed_out?
        raise SignaledError, result if result.signaled?
        raise FailedError, result unless result.success?
      end

      # Log the result of running the command
      # @return [void]
      def log_result
        options.logger.info { "PID #{pid}: #{command} exited with status #{result}" }
      end

      # Raises a ProcessIOError if the given pipe has a recorded exception
      #
      # @param option_key [Object] The redirection option key
      #
      #   For example, `:out`, or an Array like `[:out, :err]` for merged streams.
      #
      # @param pipe [ProcessExecuter::MonitoredPipe] The pipe that raised the exception
      #
      # @raise [ProcessExecuter::ProcessIOError] If there was an exception while collecting subprocess output
      #
      # @return [void]
      #
      def raise_pipe_error(option_key, pipe)
        return unless pipe.exception

        error = ProcessExecuter::ProcessIOError.new("Pipe Exception for #{command}: #{option_key.inspect}")
        raise(error, cause: pipe.exception)
      end

      # Raises a ProcessIOError if the given pipe's output was truncated
      #
      # Truncation means the pipe gave up draining before reaching EOF
      # ({MonitoredPipe#truncated?}): output the subprocess (or a descendant
      # holding the inherited write fd) produced was discarded instead of
      # being written to the destination. Raising makes that data loss loud
      # rather than letting the command appear to succeed with silently
      # incomplete output.
      #
      # @param option_key [Object] The redirection option key
      #
      # @param pipe [ProcessExecuter::MonitoredPipe] The pipe whose output was truncated
      #
      # @raise [ProcessExecuter::ProcessIOError] If the pipe's output was truncated
      #
      # @return [void]
      #
      def raise_truncation_error(option_key, pipe)
        return unless pipe.truncated?

        raise ProcessExecuter::ProcessIOError,
              "Output truncated for #{command}: #{option_key.inspect} " \
              'could not be fully collected before the close timeout'
      end
    end
  end
end
