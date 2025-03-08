# frozen_string_literal: true

module ProcessExecuter
  module Destinations
    # Handles monitored pipes
    #
    # @api private
    class MonitoredPipe < ProcessExecuter::DestinationBase
      # Writes data to the monitored pipe
      #
      # @param data [String] the data to write
      # @return [Object] the return value of the pipe's write method
      #
      # @example
      #   pipe = ProcessExecuter::MonitoredPipe.new
      #   pipe_handler = ProcessExecuter::Destinations::MonitoredPipe.new(pipe)
      #   pipe_handler.write("Data to pipe")
      def write(data)
        super
        destination.write data
      end

      # Closes the pipe if it's open
      #
      # @return [void]
      def close
        destination.close if destination.state == :open
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is a ProcessExecuter::MonitoredPipe
      def self.handles?(destination)
        destination.is_a? ProcessExecuter::MonitoredPipe
      end
    end
  end
end
