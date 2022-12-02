# frozen_string_literal: true

require 'process_executer/monitored_pipe'
require 'process_executer/options'
require 'process_executer/process'
require 'process_executer/status'

require 'timeout'

# Execute a command in a subprocess and optionally capture its output
#
# @api public
#
module ProcessExecuter
  # Execute the specified command and return the exit status
  #
  # This method blocks until the command has terminated or the timeout has been reached.
  #
  # @example
  #   status = ProcessExecuter.spawn('echo hello')
  #   status.exited? # => true
  #   status.success? # => true
  #   stdout.string # => "hello\n"
  #
  # @example with a timeout
  #   status = ProcessExecuter.spawn('sleep 10', timeout: 0.01)
  #   status.exited? # => false
  #   status.success? # => nil
  #   status.signaled? # => true
  #   status.termsig # => 9
  #
  # @see https://ruby-doc.org/core-3.1.2/Kernel.html#method-i-spawn Kernel.spawn
  #   documentation for valid command and options
  #
  # @see ProcessExecuter::Options#initialize See ProcessExecuter::Options#initialize
  #   for additional options that may be specified
  #
  # @param command [Array<String>] the command to execute
  # @param options_hash [Hash] the options to use for this execution context
  #
  # @return [ProcessExecuter::ExecutionContext] the execution context that can run commands
  #
  def self.spawn(*command, **options_hash)
    options = ProcessExecuter::Options.new(**options_hash)
    pid = ::Process.spawn(*command, **options.spawn_options)
    wait_for_process(pid, options)
  end

  # Wait for process to terminate
  #
  # If a timeout is speecified in options, kill the process after options.timeout seconds.
  #
  # @param pid [Integer] the process id
  # @param options [ProcessExecuter::Options] the options used
  #
  # @return [ProcessExecuter::Status] the status of the process
  #
  # @api private
  #
  private_class_method def self.wait_for_process(pid, options)
    Timeout.timeout(options.timeout) do
      ::Process.wait2(pid).last
    end
  rescue Timeout::Error
    ::Process.kill('KILL', pid)
    ::Process.wait2(pid).last
  end
end
