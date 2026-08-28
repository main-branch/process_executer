# frozen_string_literal: true

require_relative 'destination_base'

module ProcessExecuter
  module Destinations
    # Handles monitored pipes
    #
    # @api private
    class MonitoredPipe < DestinationBase
      # Writes data to the monitored pipe
      #
      # @example
      #   stringio_dest = StringIO.new
      #   pipe = ProcessExecuter::MonitoredPipe.new(stringio_dest)
      #   pipe_handler = ProcessExecuter::Destinations::MonitoredPipe.new(pipe)
      #   pipe_handler.write("Data to pipe")
      #
      # @param data [String] the data to write
      #
      # @return [Integer] the number of bytes written
      #
      def write(data)
        super
        destination.write data
      end

      # Does nothing: closing a caller-provided pipe is the caller's responsibility
      #
      # The library closes only pipes it creates. A {ProcessExecuter::MonitoredPipe}
      # given as a redirection destination was created by the caller, and the
      # {ProcessExecuter::MonitoredPipe} documentation makes closing it the
      # caller's responsibility.
      #
      # @return [void]
      def close; end

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
