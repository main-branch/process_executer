# frozen_string_literal: true

module ProcessExecuter
  module Destinations
    # Handles standard error redirection
    #
    # @api private
    class Stderr < ProcessExecuter::DestinationBase
      # Writes data to standard error
      #
      # @param data [String] the data to write
      # @return [Integer] the number of bytes written
      #
      # @example
      #   stderr_handler = ProcessExecuter::Destinations::Stderr.new(:err)
      #   stderr_handler.write("Error message")
      def write(data)
        super
        $stderr.write data
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is :err or 2
      def self.handles?(destination)
        [:err, 2].include?(destination)
      end
    end
  end
end
