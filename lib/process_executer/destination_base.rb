# frozen_string_literal: true

module ProcessExecuter
  # Base class for all destination handlers
  #
  # Provides the common interface and functionality for all destination
  # classes that handle different types of output redirection.
  #
  # @api private
  class DestinationBase
    # Initializes a new destination handler
    #
    # @param destination [Object] the destination to write to
    # @return [DestinationBase] a new destination handler instance
    def initialize(destination)
      @destination = destination
      @data_written = []
    end

    # The destination object this handler manages
    #
    # @return [Object] the destination object
    attr_reader :destination

    # The data written to the destination
    #
    # @return [Array<String>] the data written to the destination
    attr_reader :data_written

    # The data written to the destination as a single string
    # @return [String]
    def string
      data_written.join
    end

    # Writes data to the destination
    #
    # This is an abstract method that must be implemented by subclasses.
    #
    # @param data [String] the data to write
    # @return [void]
    # @raise [NotImplementedError] if the subclass doesn't implement this method
    def write(data)
      @data_written << data
    end

    # Closes the destination if necessary
    #
    # By default, this method does nothing. Subclasses should override
    # this method if they need to perform cleanup.
    #
    # @return [void]
    def close; end

    # Determines if this class can handle the given destination
    #
    # This is an abstract class method that must be implemented by subclasses.
    #
    # @param destination [Object] the destination to check
    # @return [Boolean] true if this class can handle the destination
    # @raise [NotImplementedError] if the subclass doesn't implement this method
    def self.handles?(destination)
      raise NotImplementedError
    end

    # Determines if this destination class can be wrapped by MonitoredPipe
    #
    # All destination types can be wrapped by MonitoredPipe unless they explicitly
    # opt out.
    #
    # @return [Boolean]
    # @api private
    def self.compatible_with_monitored_pipe? = true

    # Determines if this destination instance can be wrapped by MonitoredPipe
    #
    # @return [Boolean]
    # @api private
    def compatible_with_monitored_pipe?
      self.class.compatible_with_monitored_pipe?
    end
  end
end
