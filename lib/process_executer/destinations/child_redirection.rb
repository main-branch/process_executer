# frozen_string_literal: true

module ProcessExecuter
  module Destinations
    # Handles generic objects that respond to write
    #
    # @api private
    class ChildRedirection < ProcessExecuter::DestinationBase
      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination responds to write but is not an IO with fileno
      def self.handles?(destination)
        destination.is_a?(Array) && destination.size == 2 && destination[0] == :child
      end

      # This class should not be wrapped in a monitored pipe
      # @return [Boolean]
      # @api private
      def self.compatible_with_monitored_pipe? = false
    end
  end
end
