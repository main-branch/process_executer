# frozen_string_literal: true

module ProcessExecuter
  module Destinations
    # Handles destination for writing to multiple destinations
    #
    # The destination is an array with the first element being :tee and the rest
    # being the destinations.
    #
    # @api private
    class Tee < ProcessExecuter::DestinationBase
      # Initializes a new file path with mode and permissions destination handler
      #
      # Opens the file at the given path with the specified mode and permissions.
      #
      # @param destination [Array<String, String, Integer>] array with file path, mode, and permissions
      # @return [FilePathModePerms] a new handler instance
      # @raise [Errno::ENOENT] if the file path is invalid
      # @raise [ArgumentError] if the mode is invalid
      def initialize(destination)
        super
        @child_destinations = destination[1..].map { |dest| ProcessExecuter::Destinations.factory(dest) }
      end

      # The opened file object
      #
      # @return [File] the opened file
      attr_reader :child_destinations

      # Writes data to the file
      #
      # @param data [String] the data to write
      # @return [Integer] the number of bytes written
      # @raise [IOError] if the file is closed
      #
      # @example
      #   perms_handler = ProcessExecuter::Destinations::FilePathModePerms.new(["output.log", "w", 0644])
      #   perms_handler.write("Log entry with specific permissions")
      def write(data)
        super
        child_destinations.each { |dest| dest.write(data) }
      end

      # Closes the file if it's open
      #
      # @return [void]
      def close
        child_destinations.each(&:close)
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is an Array with path, mode, and permissions
      def self.handles?(destination)
        destination.is_a?(Array) && destination.size > 1 && destination[0] == :tee
      end
    end
  end
end
