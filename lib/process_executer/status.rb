# frozen_string_literal: true

require 'delegate'
require 'forwardable'

module ProcessExecuter
  # A simple delegator for Process::Status that adds a `timeout?` attribute
  #
  # @api public
  #
  class Status < SimpleDelegator
    extend Forwardable

    # Create a new Status object from a Process::Status and timeout flag
    #
    # @param status [Process::Status] the status to delegate to
    # @param timeout [Boolean] true if the process timed out
    #
    # @example
    #   status = Process.wait2(pid).last
    #   timeout = false
    #   ProcessExecuter::Status.new(status, timeout)
    #
    # @api public
    #
    def initialize(status, timeout)
      super(status)
      @timeout = timeout
    end

    # @!attribute [r] timeout?
    #
    # True if the process timed out and was sent the SIGKILL signal
    #
    # @example
    #   status = ProcessExecuter.spawn('sleep 10', timeout: 0.01)
    #   status.timeout? # => true
    #
    # @return [Boolean]
    #
    # @api public
    #
    def timeout? = @timeout
  end
end
