# frozen_string_literal: true

require_relative 'errors'

module ProcessExecuter
  # `Runner` runs a subprocess, blocks until it completes, and returns the result
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
  class RunnerWithCapture < Runner
    # Run a command and return the result which includes the captured output
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
      stdout_buffer = StringIO.new
      stderr_buffer = StringIO.new

      options.merge!(**capture_options(options, stdout_buffer, stderr_buffer))

      result = super

      ProcessExecuter::ResultWithCapture.new(result, stdout_buffer:, stderr_buffer:)
    end

    private

    # Determine the out and err options to add to the command options
    #
    # @param options [ProcessExecuter::Options::RunWithCaptureOptions] The options for the command
    # @param stdout_buffer [StringIO] The buffer to capture stdout
    # @param stderr_buffer [StringIO] The buffer to capture stderr
    #
    # @return [Hash] The options to add to the command
    #
    # @api private
    #
    def capture_options(options, stdout_buffer, stderr_buffer)
      {}.tap do |capture_options|
        capture_options[:out] = stdout_buffer unless options.stdout_redirection_key
        if options.merge_output
          capture_options[:err] = [:child, 1]
        else
          capture_options[:err] = stderr_buffer unless options.stderr_redirection_key
        end
      end
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
    # def process_result(result)
    #   log_result(result)
    #   raise_errors(result) if result.options.raise_errors
    # end
  end
end
