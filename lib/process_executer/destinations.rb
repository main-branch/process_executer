# frozen_string_literal: true

require_relative 'destinations/child_redirection'
require_relative 'destinations/close'
require_relative 'destinations/file_descriptor'
require_relative 'destinations/file_path'
require_relative 'destinations/file_path_mode'
require_relative 'destinations/file_path_mode_perms'
require_relative 'destinations/io'
require_relative 'destinations/monitored_pipe'
require_relative 'destinations/stderr'
require_relative 'destinations/stdout'
require_relative 'destinations/tee'
require_relative 'destinations/writer'

module ProcessExecuter
  # Collection of destination handler implementations
  #
  # @api public
  module Destinations
    # Creates appropriate destination objects based on the given raw destination
    #
    # The raw destination is the value passed to `Process.spawn` in a redirection
    # option. Typically, this is value is a file descriptor, a file path, an IO
    # object, a symbol, or an Array.
    #
    # This factory method dynamically finds and instantiates the appropriate
    # destination class for handling the provided destination.
    #
    # @example
    #   ProcessExecuter.destination_factory(1)
    #     #=> Returns a ProcessExecuter::Destinations::Stdout instance
    #   ProcessExecuter.destination_factory("output.log")
    #     #=> Returns a ProcessExecuter::Destinations::FilePath instance
    #
    # @param raw_destination [Object] the destination to create a handler for
    #
    # @return [DestinationBase] an instance of the appropriate destination handler
    #
    # @raise [ProcessExecuter::ArgumentError] if no matching destination class is found
    #
    def self.factory(raw_destination)
      destination_class = destination_class(raw_destination)
      return destination_class.new(raw_destination) if destination_class

      raise ProcessExecuter::ArgumentError, 'wrong exec redirect action'
    end

    # Determines if the given destination is compatible with a monitored pipe
    #
    # If true, this destination should not be wrapped in a monitored pipe.
    #
    # @example
    #   ProcessExecuter::Destinations.compatible_with_monitored_pipe?(1) #=> true
    #   ProcessExecuter::Destinations.compatible_with_monitored_pipe?([:child, 6]) #=> false
    #   ProcessExecuter::Destinations.compatible_with_monitored_pipe?([:close]) #=> false
    #
    # @param raw_destination [Object] the destination to check
    # @return [Boolean, nil] true if the destination is compatible with a monitored pipe
    # @raise [ProcessExecuter::ArgumentError] if no matching destination class is found
    # @api public
    def self.compatible_with_monitored_pipe?(raw_destination)
      # matching_class = matching_destination_class(destination)
      # matching_class&.compatible_with_monitored_pipe?

      matching_class = destination_class(raw_destination)
      return matching_class.compatible_with_monitored_pipe? if matching_class

      raise ProcessExecuter::ArgumentError, 'wrong exec redirect action'
    end

    # Determines the destination class that can handle the given raw destination
    # @param raw_destination [Object] the destination to check
    # @return [Class] the destination class that can handle the given raw destination
    # @api private
    def self.destination_class(raw_destination)
      matching_destination_classes =
        ProcessExecuter::Destinations.constants
                                     .map { |const| ProcessExecuter::Destinations.const_get(const) }
                                     .select { |const| const.is_a?(Class) }

      matching_destination_classes.find { |klass| klass.handles?(raw_destination) }
    end
  end
end
