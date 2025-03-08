# frozen_string_literal: true

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
    # Creates appropriate destination objects based on the given destination
    #
    # This factory method dynamically finds and instantiates the appropriate
    # destination class for handling the provided destination.
    #
    # @param destination [Object] the destination to create a handler for
    # @return [DestinationBase] an instance of the appropriate destination handler
    # @raise [ArgumentError] if no matching destination class is found
    #
    # @example
    #   ProcessExecuter.destination_factory(1) #=> Returns a Stdout instance
    #   ProcessExecuter.destination_factory("output.log") #=> Returns a FilePath instance
    def self.factory(destination)
      destination_classes =
        ProcessExecuter::Destinations.constants
                                     .map { |const| ProcessExecuter::Destinations.const_get(const) }
                                     .select { |const| const.is_a?(Class) }

      matching_class = destination_classes.find { |klass| klass.handles?(destination) }

      return matching_class.new(destination) if matching_class

      raise ArgumentError, 'wrong exec redirect action'
    end
  end
end
