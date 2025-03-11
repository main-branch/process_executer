# frozen_string_literal: true

require_relative 'base'
require_relative 'option_definition'

module ProcessExecuter
  module Options
    # Validate Process.spawn options and return Process.spawn options
    #
    # Allow subclasses to add additional options that are not passed to `Process.spawn`
    #
    # Valid options are those accepted by Process.spawn.
    #
    # @api public
    #
    class SpawnOptions < Base
      # :nocov: SimpleCov on JRuby reports hashes declared on multiple lines as not covered
      SPAWN_OPTIONS = [
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
          options.each do |option_key, value|
            spawn_options[option_key] = value if include_spawn_option?(option_key, value)
          end
        end
      end

      # Determine if the given option key indicates a redirection option
      # @param option_key [Symbol, Integer, IO, Array] the option key to be tested
      # @return [Boolean]
      # @api private
      def redirection?(option_key)
        test = ->(key) { %i[in out err].include?(key) || key.is_a?(Integer) || (key.is_a?(IO) && !key.fileno.nil?) }
        test.call(option_key) || (option_key.is_a?(Array) && option_key.all? { |key| test.call(key) })
      end

      # Does option_key indicate a standard redirection such as stdin, stdout, or stderr
      # @param option_key [Symbol, Integer, IO, Array] the option key to be tested
      # @param symbol [:in, :out, :err] the symbol to test for
      # @param fileno [Integer] the file descriptor number to test for
      # @return [Boolean]
      # @api private
      def std_redirection?(option_key, symbol, fileno)
        test = ->(key) { key == symbol || key == fileno || (key.is_a?(IO) && key.fileno == fileno) }
        test.call(option_key) || (option_key.is_a?(Array) && option_key.any? { |key| test.call(key) })
      end

      # Determine if the given option key indicates a redirection option for stdout
      # @param option_key [Symbol, Integer, IO, Array] the option key to be tested
      # @return [Boolean]
      # @api private
      def stdout_redirection?(option_key) = std_redirection?(option_key, :out, 1)

      # Determine the option key that indicates a redirection option for stdout
      # @return [Symbol, Integer, IO, Array, nil] nil if not found
      # @api private
      def stdout_redirection_key
        options.keys.find { |option_key| option_key if stdout_redirection?(option_key) }
      end

      # Determine the value of the redirection option for stdout
      # @return [Object]
      # @api private
      def stdout_redirection_value
        options[stdout_redirection_key]
      end

      # Determine if the given option key indicates a redirection option for stderr
      # @param option_key [Symbol, Integer, IO, Array] the option key to be tested
      # @return [Boolean]
      # @api private
      def stderr_redirection?(option_key) = std_redirection?(option_key, :err, 2)

      # Determine the option key that indicates a redirection option for stderr
      # @return [Symbol, Integer, IO, Array, nil] nil if not found
      # @api private
      def stderr_redirection_key
        options.keys.find { |option_key| option_key if stderr_redirection?(option_key) }
      end

      # Determine the value of the redirection option for stderr
      # @return [Object]
      # @api private
      def stderr_redirection_value
        options[stderr_redirection_key]
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
      # @param option_key [Symbol, Integer, IO] the option to be tested
      # @param value [Object] the value of the option
      # @return [Boolean] true if the given option should be passed to `Process.spawn`
      # @api private
      def include_spawn_option?(option_key, value)
        return false if value == :not_set

        redirection?(option_key) || SPAWN_OPTIONS.any? { |o| o.name == option_key }
      end

      # Spawn allows IO object and integers as options
      # @param option_key [Symbol] the option to be tested
      # @return [Boolean] true if the given option is a valid option
      # @api private
      def valid_option?(option_key)
        super || redirection?(option_key)
      end
    end
  end
end
