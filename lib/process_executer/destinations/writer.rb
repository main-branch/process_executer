# frozen_string_literal: true

module ProcessExecuter
  module Destinations
    # Handles generic objects that respond to write
    #
    # @api private
    class Writer < ProcessExecuter::DestinationBase
      # Writes data to the destination object
      #
      # @param data [String] the data to write
      # @return [Object] the return value of the destination's write method
      # @raise [NoMethodError] if the destination doesn't respond to write
      #
      # @example
      #   buffer = StringIO.new
      #   writer_handler = ProcessExecuter::Destinations::Writer.new(buffer)
      #   writer_handler.write("Hello world")
      def write(data)
        super
        destination.write data
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination responds to write but is not an IO with fileno
      def self.handles?(destination)
        destination.respond_to?(:write) && (!destination.respond_to?(:fileno) || destination.fileno.nil?)
      end
    end
  end
end
