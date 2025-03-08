# frozen_string_literal: true

module ProcessExecuter
  module Destinations
    # Handles file path destinations
    #
    # @api private
    class FilePath < ProcessExecuter::DestinationBase
      # Initializes a new file path destination handler
      #
      # Opens the file at the given path for writing.
      #
      # @param destination [String] the file path to write to
      # @return [FilePath] a new file path destination handler
      # @raise [Errno::ENOENT] if the file path is invalid
      def initialize(destination)
        super
        @file = File.open(destination, 'w', 0o644)
      end

      # The opened file object
      #
      # @return [File] the opened file
      attr_reader :file

      # Writes data to the file
      #
      # @param data [String] the data to write
      # @return [Integer] the number of bytes written
      # @raise [IOError] if the file is closed
      #
      # @example
      #   file_handler = ProcessExecuter::Destinations::FilePath.new("output.log")
      #   file_handler.write("Log entry")
      def write(data)
        super
        file.write data
      end

      # Closes the file if it's open
      #
      # @return [void]
      def close
        file.close unless file.closed?
      end

      # Determines if this class can handle the given destination
      #
      # @param destination [Object] the destination to check
      # @return [Boolean] true if destination is a String
      def self.handles?(destination)
        destination.is_a? String
      end
    end
  end
end
