# frozen_string_literal: true

require_relative 'spawn_options'
require_relative 'option_definition'

module ProcessExecuter
  module Options
    # Define options for the `ProcessExecuter.spawn_and_wait`
    #
    # @api public
    #
    class SpawnAndWaitOptions < SpawnOptions
      private

      # The options allowed for objects of this class
      # @return [Array<OptionDefinition>]
      # @api private
      def define_options
        # :nocov: SimpleCov on JRuby reports the last with the last argument line is not covered
        [
          *super,
          OptionDefinition.new(:timeout_after, default: nil, validator: method(:validate_timeout_after))
        ].freeze
        # :nocov:
      end

      # Raise an error unless timeout_after is nil or a non-negative real number
      # @return [void]
      # @raise [ArgumentError] if timeout_after is not a non-negative real number
      # @api private
      def validate_timeout_after
        return if timeout_after.nil?
        return if timeout_after.is_a?(Numeric) && timeout_after.real? && !timeout_after.negative?

        errors << "timeout_after must be nil or a non-negative real number but was #{timeout_after.inspect}"
      end
    end
  end
end
