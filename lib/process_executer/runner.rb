# frozen_string_literal: true

require_relative 'errors'

module ProcessExecuter
  # The `Runner` class executes subprocess commands and captures their status and output.
  #
  # It does the following:
  # - Run commands (`call`) with options for capturing output, handling timeouts, and merging stdout/stderr.
  # - Process command results, including logging and error handling.
  # - Raise detailed exceptions for common command failures, such as timeouts or subprocess errors.
  #
  # This class is used internally by {ProcessExecuter.run}.
  #
  # @api public
  #
  class Runner
    # Create a new RunCommand instance
    #
    # @example
    #   runner = Runner.new()
    #   result = runner.call('echo', 'hello')
    #
    # @param logger [Logger] The logger to use. Defaults to a no-op logger if nil.
    #
    def initialize(logger = Logger.new(nil))
      @logger = logger
    end

    # The logger to use
    # @example
    #   runner.logger #=> #<Logger:0x00007f9b1b8b3d20>
    # @return [Logger]
    attr_reader :logger

    # Run a command and return the status including stdout and stderr output
    #
    # @example
    #   runner = ProcessExecuter::Runner.new()
    #   result = runner.call('echo hello')
    #   result = ProcessExecuter.run('echo hello')
    #   result.success? # => true
    #   result.exitstatus # => 0
    #   result.stdout # => "hello\n"
    #   result.stderr # => ""
    #
    # @param command [Array<String>] The command to run
    # @param out [#write, Array<#write>, nil] The object (or array of objects) to which stdout is written
    # @param err [#write, Array<#write>, nil] The object (or array of objects) to which stderr is written
    # @param merge [Boolean] Write both stdout and stderr into the buffer for stdout
    # @param options_hash [Hash] Additional options to pass to Process.spawn
    #
    #   See {ProcessExecuter.run} for a full list of options.
    #
    # @return [ProcessExecuter::Result] The result of the completed subprocess
    #
    def call(*command, out: nil, err: nil, merge: false, **options_hash)
      out ||= StringIO.new
      err ||= (merge ? out : StringIO.new)

      spawn(command, out:, err:, **options_hash).tap { |result| process_result(result) }
    end

    private

    # Wrap the output buffers in pipes and then execute the command
    #
    # @param command [Array<String>] The command to execute
    # @param out [#write, Array<#write>] The object (or array of objects) to which stdout is written
    # @param err [#write, Array<#write>] The object (or array of objects) to which stderr is written
    # @param options_hash [Hash] Additional options to pass to Process.spawn
    #
    #   See {ProcessExecuter.run} for a full list of options.
    #
    # @raise [ProcessExecuter::ProcessIOError] If an exception was raised while collecting subprocess output
    # @raise [ProcessExecuter::TimeoutError] If the command times out
    #
    # @return [ProcessExecuter::Result] The result of the completed subprocess
    #
    # @api private
    #
    def spawn(command, out:, err:, **options_hash)
      out = [out] unless out.is_a?(Array)
      err = [err] unless err.is_a?(Array)
      out_pipe = ProcessExecuter::MonitoredPipe.new(*out)
      err_pipe = ProcessExecuter::MonitoredPipe.new(*err)
      ProcessExecuter.spawn_and_wait(*command, out: out_pipe, err: err_pipe, **options_hash)
    ensure
      out_pipe.close
      err_pipe.close
      raise_pipe_error(command, :stdout, out_pipe) if out_pipe.exception
      raise_pipe_error(command, :stderr, err_pipe) if err_pipe.exception
    end

    # Process the result of the command and return a ProcessExecuter::Result
    #
    # Log the command and result, and raise an error if the command failed.
    #
    # @param result [ProcessExecuter::Result] The result of the command
    #
    # @return [Void]
    #
    # @raise [ProcessExecuter::FailedError] If the command failed
    # @raise [ProcessExecuter::SignaledError] If the command was signaled
    # @raise [ProcessExecuter::TimeoutError] If the command times out
    # @raise [ProcessExecuter::ProcessIOError] If an exception was raised while collecting subprocess output
    #
    # @api private
    #
    def process_result(result)
      log_result(result)

      return unless result.options.raise_errors

      raise TimeoutError, result if result.timed_out?
      raise SignaledError, result if result.signaled?
      raise FailedError, result unless result.success?
    end

    # Log the result of running the command
    # @param result [ProcessExecuter::Result] the result of the command including
    #   the command, status, stdout, and stderr
    # @return [void]
    # @api private
    def log_result(result)
      logger.info { "#{result.command} exited with status #{result}" }
      logger.debug { "stdout:\n#{result.stdout.inspect}\nstderr:\n#{result.stderr.inspect}" }
    end

    # Raise an error when there was exception while collecting the subprocess output
    #
    # @param command [Array<String>] The command that was executed
    # @param pipe_name [Symbol] The name of the pipe that raised the exception
    # @param pipe [ProcessExecuter::MonitoredPipe] The pipe that raised the exception
    #
    # @raise [ProcessExecuter::ProcessIOError]
    #
    # @return [void] This method always raises an error
    #
    # @api private
    #
    def raise_pipe_error(command, pipe_name, pipe)
      error = ProcessExecuter::ProcessIOError.new("Pipe Exception for #{command}: #{pipe_name}")
      raise(error, cause: pipe.exception)
    end
  end
end
