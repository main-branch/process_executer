# frozen_string_literal: true

module ProcessExecuter
  module Options
    # Defines an option that can be used by an Options object
    #
    # @api public
    #
    class OptionDefinition
      # The name of the option
      #
      # @example
      #   option = ProcessExecuter::Options::OptionDefinition.new(:timeout_after)
      #   option.name # => :timeout_after
      #
      # @return [Symbol]
      #
      attr_reader :name

      # The default value of the option
      #
      # @example
      #   option = ProcessExecuter::Options::OptionDefinition.new(:timeout_after, default: 10)
      #   option.default # => 10
      #
      # @return [Object]
      #
      attr_reader :default

      # A method or proc that validates the option
      #
      # @example
      #   option = ProcessExecuter::Options::OptionDefinition.new(
      #     :timeout_after, validator: method(:validate_timeout_after)
      #   )
      #   option.validator # => #<Method: ProcessExecuter#validate_timeout_after>
      #
      # @return [Method, Proc, nil]
      #
      attr_reader :validator

      # Create a new option definition
      #
      # @example
      #   option = ProcessExecuter::Options::OptionDefinition.new(
      #     :timeout_after, default: 10, validator: -> { timeout_after.is_a?(Numeric) }
      #   )
      #
      def initialize(name, default: nil, validator: nil)
        @name = name
        @default = default
        @validator = validator
      end
    end
  end
end
