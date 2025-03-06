# frozen_string_literal: true

require 'process_executer/option_definition'

module ProcessExecuter
  # Defines, validates, and holds a set of option values
  #
  # Options are defined by subclasses by overriding the `define_options` method.
  #
  # @example Define an options class with two options
  #   class MyOptions < ProcessExecuter::Options
  #     def define_options
  #       # Call super to include options defined in the parent class
  #       [
  #         *super,
  #         ProcessExecuter::OptionDefinition.new(:option1),
  #         ProcessExecuter::OptionDefinition.new(:option2)
  #       ]
  #     end
  #   end
  #   options_hash = { options1: 'value1', option2: 'value2' }
  #   options = MyOptions.new(options_hash)
  #   options.option1 # => 'value1'
  #   options.option2 # => 'value2'
  #
  # @api public
  class Options
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
      options.each_key do |option|
        validator = allowed_options[option].validator
        instance_exec(&validator.to_proc) if validator.is_a?(Method) || validator.is_a?(Proc)
      end
    end

    # Define accessor methods for each option
    # @return [void]
    # @api private
    def define_accessor_methods
      allowed_options.each_key do |option|
        define_singleton_method(option) do
          @options[option]
        end

        define_singleton_method("#{option}=") do |value|
          @options[option] = value
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

      # :nocov: SimpleCov on JRuby reports the last with the last argument line is not covered
      raise(
        ArgumentError,
        "Unknown option#{unknown_options.count > 1 ? 's' : ''}: #{unknown_options.join(', ')}"
      )
      # :nocov:
    end
  end

  # Validate Process.spawn options and return Process.spawn options
  #
  # Allow subclasses to add additional options that are not passed to `Process.spawn`
  #
  # Valid options are those accepted by Process.spawn plus the following additions:
  #
  # * `:timeout_after`: the number of seconds to allow a process to run before killing it
  #
  # @api public
  #
  class SpawnOptions < Options
    # :nocov: SimpleCov on JRuby reports hashes declared on multiple lines as not covered
    SPAWN_OPTIONS = [
      OptionDefinition.new(:in, default: :not_set),
      OptionDefinition.new(:out, default: :not_set),
      OptionDefinition.new(:err, default: :not_set),
      OptionDefinition.new(:unsetenv_others, default: :not_set),
      OptionDefinition.new(:pgroup, default: :not_set),
      OptionDefinition.new(:new_pgroup, default: :not_set),
      OptionDefinition.new(:rlimit_resourcename, default: :not_set),
      OptionDefinition.new(:umask, default: :not_set),
      OptionDefinition.new(:close_others, default: :not_set),
      OptionDefinition.new(:chdir, default: :not_set)
    ].freeze
    # :nocov:

    # Returns the options to be passed to Process.spawn
    #
    # @example
    #   options = ProcessExecuter::Options.new(out: $stdout, err: $stderr, timeout_after: 10)
    #   options.spawn_options # => { out: $stdout, err: $stderr }
    #
    # @return [Hash]
    #
    def spawn_options
      {}.tap do |spawn_options|
        options.each do |option, value|
          spawn_options[option] = value if include_spawn_option?(option, value)
        end
      end
    end

    private

    # Define the allowed options
    #
    # @example Adding new options in a subclass
    #   class MyOptions < SpawnOptions
    #     def define_options
    #       super.merge(timeout_after: { default: nil, validator: nil })
    #     end
    #   end
    #
    # @return [Hash<Symbol, Hash>]
    #
    # @api private
    def define_options
      [*super, *SPAWN_OPTIONS].freeze
    end

    # Determine if the given option should be passed to `Process.spawn`
    # @param option [Symbol, Integer, IO] the option to be tested
    # @param value [Object] the value of the option
    # @return [Boolean] true if the given option should be passed to `Process.spawn`
    # @api private
    def include_spawn_option?(option, value)
      value != :not_set &&
        (option.is_a?(Integer) || option.is_a?(IO) || SPAWN_OPTIONS.any? { |o| o.name == option })
    end

    # Spawn allows IO object and integers as options
    # @param option [Symbol] the option to be tested
    # @return [Boolean] true if the given option is a valid option
    # @api private
    def valid_option?(option)
      super || option.is_a?(Integer) || option.respond_to?(:fileno)
    end
  end

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
        OptionDefinition.new(:timeout_after, default: nil, validator: method(:validate_timeout_after)),
        OptionDefinition.new(:logger, default: Logger.new(nil), validator: method(:validate_logger))
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

      # :nocov: SimpleCov on SimpleCov on JRuby reports the last with the last argument line is not covered
      raise(
        ArgumentError,
        "timeout_after must be nil or a non-negative real number but was #{timeout_after.inspect}"
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
        OptionDefinition.new(:merge, default: false, validator: method(:validate_merge)),
        OptionDefinition.new(:raise_errors, default: true, validator: method(:validate_raise_errors))
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

    # Validate the merge option value
    # @return [String, nil] the error message if the value is not valid
    # @api private
    def validate_merge
      return if [true, false].include?(merge)

      # :nocov: SimpleCov on JRuby reports the last with the last argument line is not covered
      raise(
        ArgumentError,
        "merge must be true or false but was #{merge.inspect}"
      )
      # :nocov:
    end
  end
end
