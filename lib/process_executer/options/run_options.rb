# frozen_string_literal: true

require_relative 'spawn_and_wait_options'
require_relative 'option_definition'

module ProcessExecuter
  module Options
    # Define options for the `ProcessExecuter.run`
    #
    # @api public
    #
    class RunOptions < SpawnAndWaitOptions
      private

      # :nocov: SimpleCov on JRuby reports the last with the last argument line is not covered

      # The options allowed for objects of this class
      # @return [Array<OptionDefinition>]
      # @api private
      def define_options
        [
          *super,
          OptionDefinition.new(:raise_errors, default: true, validator: method(:validate_raise_errors)),
          OptionDefinition.new(:logger, default: Logger.new(nil), validator: method(:validate_logger))
        ].freeze
      end
      # :nocov:

      # Validate the raise_errors option value
      # @return [String, nil] the error message if the value is not valid
      # @api private
      def validate_raise_errors
        return if [true, false].include?(raise_errors)

        # :nocov: SimpleCov on JRuby reports the last with the last argument line is not covered
        raise(
          ArgumentError,
          "raise_errors must be true or false but was #{raise_errors.inspect}"
        )
        # :nocov:
      end

      # Validate the logger option value
      # @return [String, nil] the error message if the value is not valid
      # @api private
      def validate_logger
        return if logger.respond_to?(:info) && logger.respond_to?(:debug)

        # :nocov: SimpleCov on JRuby reports the last with the last argument line is not covered
        raise(
          ArgumentError,
          "logger must respond to #info and #debug but was #{logger.inspect}"
        )
        # :nocov:
      end
    end
  end
end
