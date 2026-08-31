# frozen_string_literal: true

require_relative '../errors'

module ProcessExecuter
  module Commands
    # Runs a subprocess, blocks until it completes, and returns the result
    #
    # Extends {ProcessExecuter::Commands::Run} to provide the core functionality for
    # {ProcessExecuter.run_with_capture}.
    #
    # It accepts all [Process.spawn execution
    # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options)
    # plus the additional options `timeout_after`, `raise_errors`, `logger`, and
    # `merge_output`.
    #
    # Like {Run}, any stdout or stderr redirection destinations are wrapped in a
    # {MonitoredPipe}.
    #
    # @api private
    #
    class RunWithCapture < Run
      # Run a command and return the result which includes the captured output
      #
      # @example
      #   options = ProcessExecuter::Options::RunWithCaptureOptions.new(merge_output: false)
      #   result = ProcessExecuter::Commands::RunWithCapture.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
      #   result.stdout # => "hello\n"
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
      #   collecting subprocess output
      #
      # @return [ProcessExecuter::ResultWithCapture] The result of the completed subprocess
      #
      def call
        @stdout_buffer = StringIO.new
        stdout_buffer.set_encoding(options.effective_stdout_encoding)
        @stderr_buffer = StringIO.new
        stderr_buffer.set_encoding(options.effective_stderr_encoding)

        begin
          super
        ensure
          log_command_output
        end
      end

      # The buffer used to capture stdout
      #
      # @example
      #   run.stdout_buffer #=> StringIO
      #
      # @return [StringIO]
      #
      attr_reader :stdout_buffer

      # The buffer used to capture stderr
      #
      # @example
      #   run.stderr_buffer #=> StringIO
      #
      # @return [StringIO]
      #
      attr_reader :stderr_buffer

      private

      # Create a result object that includes the captured stdout and stderr
      #
      # @return [ProcessExecuter::ResultWithCapture] The result of the command with captured output
      #
      def create_result
        ProcessExecuter::ResultWithCapture.new(
          super, stdout_buffer:, stderr_buffer:
        )
      end

      # The stdout and stderr capture redirections
      #
      # Called by {Run#call} to seed the redirection overrides, so the capture
      # redirections are layered on top of the user's options at spawn time
      # without writing into {#options} or mutating the parent's state.
      #
      # When the user gives a combined redirection whose key covers both stdout
      # and stderr (e.g. `[:out, :err] => destination`), a single capture
      # redirection is built for that key so both streams are interleaved into
      # {#stdout_buffer} and {#stderr_buffer} is left empty, mirroring the
      # `merge_output: true` contract.
      #
      # @return [Hash<Object, Object>]
      #
      def internal_redirections
        if options.combined_stdout_and_stderr_redirection?
          combined_capture_redirection
        else
          stdout_and_stderr_capture_redirections
        end
      end

      # A single capture redirection for a combined stdout/stderr key
      #
      # Both streams are interleaved into {#stdout_buffer}; {#stderr_buffer} is
      # left empty.
      #
      # @return [Hash<Object, Object>]
      #
      def combined_capture_redirection
        tee_capture_redirection(
          options.stdout_redirection_source, options.stdout_redirection_destination, stdout_buffer
        )
      end

      # Separate capture redirections for stdout and stderr
      #
      # If `merge_output: true` was given, stderr is redirected into stdout so
      # both streams are interleaved into {#stdout_buffer}.
      #
      # @return [Hash<Object, Object>]
      #
      def stdout_and_stderr_capture_redirections
        stdout_capture_redirection.merge(stderr_capture_redirection)
      end

      # The redirection that captures stdout into {#stdout_buffer}
      #
      # Tees the buffer onto the user's stdout redirection if one was given;
      # otherwise installs the plain default capture redirection.
      #
      # @return [Hash<Object, Object>]
      #
      def stdout_capture_redirection
        source = options.stdout_redirection_source
        return default_capture_redirection(:out, stdout_buffer) unless source

        tee_capture_redirection(source, options.stdout_redirection_destination, stdout_buffer)
      end

      # The redirection that captures stderr
      #
      # Stderr is captured into {#stderr_buffer}, or into stdout (and thereby
      # {#stdout_buffer}) if `merge_output: true` was given. Tees the capture
      # destination onto the user's stderr redirection if one was given;
      # otherwise installs the plain default capture redirection.
      #
      # @return [Hash<Object, Object>]
      #
      def stderr_capture_redirection
        capture_destination = options.merge_output ? [:child, 1] : stderr_buffer
        source = options.stderr_redirection_source
        return default_capture_redirection(:err, capture_destination) unless source

        tee_capture_redirection(source, options.stderr_redirection_destination, capture_destination)
      end

      # Tee the capture destination onto the redirection the user gave
      #
      # If the user's destination is already a tee, the capture destination is
      # added to it; otherwise the user's destination and the capture
      # destination are wrapped in a new tee.
      #
      # @param source [Symbol, Integer, Array] The redirection source the user gave
      # @param destination [Object] The redirection destination the user gave
      # @param capture_destination [Object] The additional destination to capture output to
      # @return [Hash] The redirection to merge into options
      def tee_capture_redirection(source, destination, capture_destination)
        if Destinations::Tee.handles?(destination)
          { source => destination + [capture_destination] }
        else
          { source => [:tee, destination, capture_destination] }
        end
      end

      # The plain capture redirection used when the user gave no redirection
      #
      # @param source [Symbol] The redirection source (:out or :err)
      # @param capture_destination [Object] The destination to capture output to
      # @return [Hash] The redirection to merge into options
      def default_capture_redirection(source, capture_destination)
        { source => capture_destination }
      end

      # Log the captured command output to the given logger at debug level
      # @return [Void]
      def log_command_output
        options.logger&.debug { "PID #{pid}: stdout: #{stdout_buffer.string.inspect}" }
        options.logger&.debug { "PID #{pid}: stderr: #{stderr_buffer.string.inspect}" }
      end
    end
  end
end
