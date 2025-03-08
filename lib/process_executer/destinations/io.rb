# frozen_string_literal: true

module ProcessExecuter
  module Destinations
    # Handles IO objects
    #
    # @api private
    class IO < ProcessExecuter::DestinationBase
      # Writes data to the IO object
      #
      # @param data [String] the data to write
      # @return [Integer] the number of bytes written
      # @raise [IOError] if the IO object is closed
      #
      # @example
      #   io = File.open('file.txt', 'w')
      #   io_handler = ProcessExecuter::Destinations::IO.new(io)
      #   io_handler.write("Hello world")
      def write(data)
        super
        destination.write data
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is an IO with a valid file descriptor
      def self.handles?(destination)
        destination.is_a?(::IO) && destination.respond_to?(:fileno) && destination.fileno
      end
    end
  end
end
