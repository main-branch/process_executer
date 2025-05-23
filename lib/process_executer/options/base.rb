# frozen_string_literal: true

require_relative 'option_definition'

module ProcessExecuter
  module Options
    # Defines, validates, and holds a set of option values
    #
    # Options are defined by subclasses by overriding the `define_options` method.
    #
    # @example Define an options class with two options
    #   class MyOptions < ProcessExecuter::Options::Base
    #     def define_options
    #       # Call super to include options defined in the parent class
    #       [
    #         *super,
    #         ProcessExecuter::Options::OptionDefinition.new(:option1),
    #         ProcessExecuter::Options::OptionDefinition.new(:option2)
    #       ]
    #     end
    #   end
    #   options_hash = { options1: 'value1', option2: 'value2' }
    #   options = MyOptions.new(options_hash)
    #   options.option1 # => 'value1'
    #   options.option2 # => 'value2'
    #
    # @api public
    class Base
      # Create a new Options object
      #
      # @example
      #   options = ProcessExecuter::Options.new(out: $stdout, err: $stderr, timeout_after: 10)
      #
      # @param options [Hash] Process.spawn options plus additional options listed below.
      #
      #   See [Process.spawn](https://ruby-doc.org/core/Process.html#method-c-spawn)
      #   for a list of valid options that can be passed to `Process.spawn`.
      #
      # @option options [Integer, Float, nil] :timeout_after
      #   Number of seconds to wait for the process to terminate. Any number
      #   may be used, including Floats to specify fractional seconds. A value of 0 or nil
      #   will allow the process to run indefinitely.
      #
      def initialize(**options)
        @options = allowed_options.transform_values(&:default).merge(options)
        @errors = []
        assert_no_unknown_options
        define_accessor_methods
        validate_options
      end

      # All the allowed options as a hash whose keys are the option names
      #
      # The returned hash what is returned from `define_options` but with the
      # option names as keys. The values are instances of `OptionDefinition`.
      #
      # The returned hash is frozen and cannot be modified.
      #
      # @example
      #   options.allowed_options # => { timeout_after: #<OptionDefinition>, ... }
      #
      # @return [Hash]
      #
      def allowed_options
        @allowed_options ||=
          define_options.each_with_object({}) do |option, hash|
            hash[option.name] = option
          end.freeze
      end

      # A string representation of the object that includes the options
      # @example
      #   options = ProcessExecuter::Options.new(option1: 'value1', option2: 'value2')
      #   options.to_s # => #<ProcessExecuter::Options:0x00007f8f9b0b3d20 option1: "value1", option2: "value2">'
      # @return [String]
      def to_s
        "#{super.to_s[0..-2]} #{inspect}>"
      end

      # A string representation of the options
      # @example
      #   options = ProcessExecuter::Options.new(option1: 'value1', option2: 'value2')
      #   options.inspect # => '{:option1=>"value1", :option2=>"value2"}'
      # @return [String]
      def inspect
        options.inspect
      end

      # A hash representation of the options
      # @example
      #   options = ProcessExecuter::Options.new(option1: 'value1', option2: 'value2')
      #   options.to_h # => { option1: "value1", option2: "value2" }
      # @return [Hash]
      def to_h
        @options.dup
      end

      # Iterate over each option with an object
      # @example
      #   options = ProcessExecuter::Options.new(option1: 'value1', option2: 'value2')
      #   options.each_with_object({}) { |(option_key, option_value), obj| obj[option_key] = option_value }
      #   # => { option1: "value1", option2: "value2" }
      # @yield [option_key, option_value, obj]
      # @return [void]
      def each_with_object(obj, &)
        @options.each_with_object(obj, &)
      end

      # Merge the given options into the current options
      # @example
      #   options = ProcessExecuter::Options.new(option1: 'value1', option2: 'value2')
      #   options.merge!(option2: 'new_value2', option3: 'value3')
      #   options.option2 # => 'new_value2'
      #   options.option3 # => 'value3'
      #
      # @param other_options [Hash] the options to merge into the current options
      # @return [void]
      def merge!(**other_options)
        @options.merge!(other_options)
      end

      # A shallow copy of self with options copied but not the values they reference
      #
      # If any keyword arguments are given, the copy will be created with the
      # respective option values updated.
      #
      # @example
      #   options_hash = { option1: 'value1', option2: 'value2' }
      #   options = ProcessExecuter::MyOptions.new(options_hash)
      #   copy = options.with(option1: 'new_value1')
      #   copy.option1 # => 'new_value1'
      #   copy.option2 # => 'value2'
      #   options.option1 # => 'value1'
      #   options.option2 # => 'value2'
      #
      # @param options_hash [Hash] the options to merge into the current options
      #
      # @return [self.class]
      #
      def with(**options_hash)
        self.class.new(**@options, **options_hash)
      end

      # The list of validation errors
      #
      # Validators should add an error messages to this array.
      #
      # @example
      #   options = ProcessExecuter::Options::RunOptions.new(timeout_after: 'not_a_number', raise_errors: 'yes')
      #   #=> raises an Argument error with the following message:
      #       timeout_after must be nil or a non-negative real number but was "not_a_number"
      #       raise_errors must be true or false but was "yes""
      #    errors # => [
      #      "timeout_after must be nil or a non-negative real number but was \"not_a_number\"",
      #      "raise_errors must be true or false but was \"yes\""
      #    ]
      #
      # @return [Array<String>]
      # @api private
      attr_reader :errors

      protected

      # An array of OptionDefinition objects that define the allowed options
      #
      # Subclasses MUST override this method to define the allowed options.
      #
      # @return [Array<OptionDefinition>]
      #
      # @api private
      #
      def define_options
        [].freeze
      end

      # Determine if the given option is a valid option
      #
      # May be overridden by subclasses to add additional validation.
      #
      # @param option [Symbol] the option to be tested
      # @return [Boolean] true if the given option is a valid option
      # @api private
      def valid_option?(option)
        allowed_options.keys.include?(option)
      end

      private

      # @!attribute [r]
      #
      # A hash of all options keyed by the option name
      #
      # @return [Hash{Symbol => Object}]
      #
      # @api private
      #
      attr_reader :options

      # Raise an argument error for invalid option values
      # @return [void]
      # @raise [ArgumentError] if any invalid option values are found
      # @api private
      def validate_options
        options.each_key do |option_key|
          validator = allowed_options[option_key]&.validator
          instance_exec(&validator.to_proc) unless validator.nil?
        end

        raise ArgumentError, errors.join("\n") unless errors.empty?
      end

      # Define accessor methods for each option
      # @return [void]
      # @api private
      def define_accessor_methods
        allowed_options.each_key do |option|
          define_singleton_method(option) do
            @options[option]
          end
        end
      end

      # Determine if the options hash contains any unknown options
      # @return [void]
      # @raise [ArgumentError] if the options hash contains any unknown options
      # @api private
      def assert_no_unknown_options
        unknown_options = options.keys.reject { |key| valid_option?(key) }

        return if unknown_options.empty?

        raise(
          ArgumentError,
          "Unknown option#{unknown_options.count > 1 ? 's' : ''}: #{unknown_options.join(', ')}"
        )
      end
    end
  end
end
