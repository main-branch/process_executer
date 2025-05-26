# frozen_string_literal: true

module ProcessExecuter
  # rubocop:disable Layout/LineLength

  # Base class for all {ProcessExecuter} errors
  #
  # It is recommended to rescue {ProcessExecuter::Error} to catch any runtime error
  # raised by this gem unless you need more specific error handling.
  #
  # Custom errors are arranged in the following class hierarchy:
  #
  # ```text
  # ::StandardError
  #   └─> Error
  #       ├─> ArgumentError
  #       ├─> CommandError
  #       │   ├─> FailedError
  #       │   └─> SignaledError
  #       │       └─> TimeoutError
  #       ├─> ProcessIOError
  #       └─> SpawnError
  # ```
  #
  # | Error Class | Description |
  # | --- | --- |
  # | `Error` | This catch-all error serves as the base class for other custom errors. |
  # | `ArgumentError` | Raised when an invalid argument is passed to a method. |
  # | `CommandError` | A subclass of this error is raised when there is a problem executing a command. |
  # | `FailedError` | Raised when the command exits with a non-zero status code. |
  # | `SignaledError` | Raised when the command is terminated as a result of receiving a signal. This could happen if the process is forcibly terminated or if there is a serious system error. |
  # | `TimeoutError` | This is a specific type of `SignaledError` that is raised when the command times out and is killed via the SIGKILL signal. Raised when the operation takes longer than the specified timeout duration (if provided). |
  # | `ProcessIOError` | Raised when an error was encountered reading or writing to the command's subprocess. |
  # | `SpawnError` | Raised when the process could not execute. Check the  |
  #
  # @example Rescuing any error
  #   begin
  #     ProcessExecuter.run_command('git', 'status')
  #   rescue ProcessExecuter::Error => e
  #     puts "An error occurred: #{e.message}"
  #   end
  #
  # @example Rescuing a timeout error
  #   begin
  #     timeout_after = 0.1 # seconds
  #     ProcessExecuter.run_command('sleep', '1', timeout_after:)
  #   rescue ProcessExecuter::TimeoutError => e # Catch the more specific error first!
  #     puts "Command took too long and timed out: #{e}"
  #   rescue ProcessExecuter::Error => e
  #     puts "Some other error occured: #{e}"
  #   end
  #
  # @api public
  #
  class Error < ::StandardError; end

  # rubocop:enable Layout/LineLength

  # Raised when an invalid argument is passed to a method
  #
  # @example
  #   begin
  #     # Command should not be an array
  #     ProcessExecuter.run(nil, timeout_after: -1)
  #   rescue ProcessExecuter::ArgumentError => e
  #     e.message #=> "Command elements must be a String"
  #   end
  #
  class ArgumentError < ProcessExecuter::Error; end

  # Raised when a command fails or exits because of an uncaught signal
  #
  # The command executed, status, stdout, and stderr are available from this
  # object.
  #
  # The Gem will raise a more specific error for each type of failure:
  #
  # * {FailedError}: when the command exits with a non-zero status
  # * {SignaledError}: when the command exits because of an uncaught signal
  # * {TimeoutError}: when the command times out
  #
  # @api public
  #
  class CommandError < ProcessExecuter::Error
    # Create a CommandError object
    #
    # @example
    #   `exit 1` # set $? appropriately for this example
    #   result = ProcessExecuter::Result.new(%w[git status], $?, 'stdout', 'stderr')
    #   error = ProcessExecuter::CommandError.new(result)
    #   error.to_s #=> '["git", "status"], status: pid 89784 exit 1, stderr: "stderr"'
    #
    # @param result [Result] The result of the command including the command,
    #   status, stdout, and stderr
    #
    def initialize(result)
      @result = result
      super(error_message)
    end

    # The human readable representation of this error
    #
    # @example
    #   error.error_message #=> '["git", "status"], status: pid 89784 exit 1, stderr: "stderr"'
    #
    # @return [String]
    #
    def error_message
      "#{result.command}, status: #{result}"
    end

    # @attribute [r] result
    #
    # The result of the command including the command, its status and its output
    #
    # @example
    #   error.result #=> #<ProcessExecuter::Result:0x00007f9b1b8b3d20>
    #
    # @return [Result]
    #
    attr_reader :result
  end

  # Raised when the command returns a non-zero exitstatus
  #
  # @api public
  #
  class FailedError < ProcessExecuter::CommandError; end

  # Raised when the command exits because of an uncaught signal
  #
  # @api public
  #
  class SignaledError < ProcessExecuter::CommandError; end

  # Raised when the command takes longer than the configured timeout_after
  #
  # @example
  #   result.timed_out? #=> true
  #
  # @api public
  #
  class TimeoutError < ProcessExecuter::SignaledError; end

  # Raised when the output of a command can not be read
  #
  # @api public
  #
  class ProcessIOError < ProcessExecuter::Error; end

  # Raised when spawn could not execute the process
  #
  # See the `cause` for the exception that Process.spawn raised.
  #
  # @api public
  #
  class SpawnError < ProcessExecuter::Error; end
end
