# frozen_string_literal: true

require_relative 'errors'

module ProcessExecuter
  # Run a command and return the result
  #
  # This class is a wrapper around {ProcessExecuter.spawn_with_timeout} which itself is
  # a wrapper around `Process.spawn`. It takes the same options as both of these methodds
  # plus `raise_errors:` and `logger:`.
  #
  # This class wraps any stdout or stderr redirection destinations in a {MonitoredPipe}.
  # This allows any class that implements `#write` to be use as an output redirection
  # destination. This means that you can redirect to a StringIO which is not possible
  # with `Process.spawn`.
  #
  # @api public
  #
  class Runner
    # Run a command and return the status
    #
    # @example
    #   runner = ProcessExecuter::Runner.new()
    #   result = runner.call('echo hello')
    #   result = ProcessExecuter.run('echo hello')
    #   result.success? # => true
    #   result.exitstatus # => 0
    #
    # @param command [Array<String>] The command to run
    # @param options [ProcessExecuter::Options::RunOptions] Options for running the command
    #
    # @return [ProcessExecuter::Result] The result of the completed subprocess
    #
    def call(command, options)
      spawn(command, options).tap { |result| process_result(result) }
    end

    private

    # Wrap the output buffers in pipes and then execute the command
    #
    # @param command [Array<String>] The command to execute
    # @param options [ProcessExecuter::Options::RunOptions] Options for running the command
    #
    # @raise [ProcessExecuter::Error] if the command could not be executed or failed
    #
    # @return [ProcessExecuter::Result] The result of the completed subprocess
    #
    # @api private
    #
    def spawn(command, options)
      opened_pipes = wrap_stdout_stderr(options)
      ProcessExecuter.spawn_with_timeout(*command, options)
    ensure
      opened_pipes.each_value(&:close)
      opened_pipes.each { |option_key, pipe| raise_pipe_error(command, option_key, pipe) }
    end

    # Wrap the stdout and stderr redirection options with a MonitoredPipe
    # @param options [ProcessExecuter::Options::RunOptions] Options for running the command
    # @return [Hash<Object, ProcessExecuter::MonitoredPipe>] The opened pipes (the Object is the option key)
    # @api private
    def wrap_stdout_stderr(options)
      options.each_with_object({}) do |key_value, opened_pipes|
        key, value = key_value

        next unless should_wrap?(options, key, value)

        wrapped_destination = ProcessExecuter::MonitoredPipe.new(value)
        opened_pipes[key] = wrapped_destination
        options.merge!(key => wrapped_destination)
      end
    end

    # Should the redirection option be wrapped by a MonitoredPipe
    # @param key [Object] The option key
    # @param value [Object] The option value
    # @return [Boolean] Whether the option should be wrapped
    # @api private
    def should_wrap?(options, key, value)
      (options.stdout_redirection?(key) || options.stderr_redirection?(key)) &&
        ProcessExecuter::Destinations.compatible_with_monitored_pipe?(value)
    end

    # Process the result of the command and return a ProcessExecuter::Result
    #
    # Log the command and result, and raise an error if the command failed.
    #
    # @param result [ProcessExecuter::Result] The result of the command
    #
    # @return [Void]
    #
    # @raise [ProcessExecuter::Error] if the command could not be executed or failed
    #
    # @api private
    #
    def process_result(result)
      log_result(result)

      raise_errors(result) if result.options.raise_errors
    end

    # Raise an error if the command failed
    # @return [void]
    # @raise [ProcessExecuter::FailedError] If the command failed
    # @raise [ProcessExecuter::SignaledError] If the command was signaled
    # @raise [ProcessExecuter::TimeoutError] If the command times out
    # @api private
    def raise_errors(result)
      raise TimeoutError, result if result.timed_out?
      raise SignaledError, result if result.signaled?
      raise FailedError, result unless result.success?
    end

    # Log the result of running the command
    # @param result [ProcessExecuter::Result] the result of the command including
    #   the command, options, and status
    # @return [void]
    # @api private
    def log_result(result)
      result.options.logger.info { "#{result.command} exited with status #{result}" }
    end

    # Raise an error when there was exception while collecting the subprocess output
    #
    # @param command [Array<String>] The command that was executed
    # @param option_key [Symbol] The name of the pipe that raised the exception
    # @param pipe [ProcessExecuter::MonitoredPipe] The pipe that raised the exception
    #
    # @raise [ProcessExecuter::ProcessIOError]
    #
    # @return [void] This method always raises an error
    #
    # @api private
    #
    def raise_pipe_error(command, option_key, pipe)
      return unless pipe.exception

      error = ProcessExecuter::ProcessIOError.new("Pipe Exception for #{command}: #{option_key.inspect}")
      raise(error, cause: pipe.exception)
    end
  end
end
