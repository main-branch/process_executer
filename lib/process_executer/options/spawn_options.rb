# frozen_string_literal: true

require_relative 'base'
require_relative 'option_definition'

module ProcessExecuter
  module Options
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
    class SpawnOptions < Base
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
          options.each do |option_key, value|
            spawn_options[option_key] = value if include_spawn_option?(option_key, value)
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
      # @param option_key [Symbol, Integer, IO] the option to be tested
      # @param value [Object] the value of the option
      # @return [Boolean] true if the given option should be passed to `Process.spawn`
      # @api private
      def include_spawn_option?(option_key, value)
        return false if value == :not_set

        redirection_option?(option_key) || SPAWN_OPTIONS.any? { |o| o.name == option_key }
      end

      # Determine if the given option key indicates a non-array redirection option
      # @param option_key [Symbol, Integer, IO, Array] the option key to be tested
      # @return [Boolean]
      # @api private
      def non_array_redirection_option?(option_key)
        %i[in out err].include?(option_key) ||
          option_key.is_a?(Integer) ||
          (option_key.is_a?(IO) && !option_key.fileno.nil?)
      end

      # Determine if the given option key indicates an array redirection option
      # @param option_key [Symbol, Integer, IO, Array] the option key to be tested
      # @return [Boolean]
      # @api private
      def array_redirection_option?(option_key)
        option_key.is_a?(Array) && option_key.all? { |source| non_array_redirection_option?(source) }
      end

      # Determine if the given option key indicates a redirection option
      # @param option_key [Symbol, Integer, IO, Array] the option key to be tested
      # @return [Boolean]
      # @api private
      def redirection_option?(option_key)
        non_array_redirection_option?(option_key) || array_redirection_option?(option_key)
      end

      # Spawn allows IO object and integers as options
      # @param option [Symbol] the option to be tested
      # @return [Boolean] true if the given option is a valid option
      # @api private
      def valid_option?(option_key)
        super || redirection_option?(option_key)
      end
    end
  end
end
