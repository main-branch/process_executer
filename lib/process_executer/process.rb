# frozen_string_literal: true

module ProcessExecuter
  # Spawns a process and knows how to check if the process is terminated
  #
  # This class is not currently used in this Gem.
  #
  # @api public
  #
  class Process
    # Spawns a new process using Process.spawn
    #
    # @example
    #   command = ['echo', 'hello world']
    #   options = { chdir: '/tmp' }
    #   process = ProcessExecuter::Process.new(*command, **options)
    #   process.pid # => 12345
    #   process.terminated? # => true
    #   process.status # => #<Process::Status: pid 12345 exit 0>
    #
    # @see https://ruby-doc.org/core/Process.html#method-c-spawn Process.spawn documentation
    #
    # @param command [Array] the command to execute
    # @param spawn_options [Hash] the options to pass to Process.spawn
    #
    def initialize(*command, **spawn_options)
      @pid = ::Process.spawn(*command, **spawn_options)
    end

    # @!attribute [r]
    #
    # The id of the process
    #
    # @example
    #   ProcessExecuter::Process.new('echo', 'hello world').pid # => 12345
    #
    # @return [Integer] The id of the process
    #
    attr_reader :pid

    # @!attribute [r]
    #
    # The exit status of the process or `nil` if the process has not terminated
    #
    # @example
    #   ProcessExecuter::Process.new('echo', 'hello world').status # => #<Process::Status: pid 12345 exit 0>
    #
    # @return [::Process::Status, nil]
    #
    #   The status is set only when `terminated?` is called and returns `true`.
    #
    attr_reader :status

    # Return true if the process has terminated
    #
    # If the proces has terminated, `#status` is set to the exit status of the process.
    #
    # @example
    #   process = ProcessExecuter::Process.new('echo', 'hello world')
    #   sleep 1
    #   process.terminated? # => true
    #
    # @return [Boolean] true if the process has terminated
    #
    def terminated?
      return true if @status

      _pid, @status = ::Process.wait2(pid, ::Process::WNOHANG)
      !@status.nil?
    end
  end
end
