# frozen_string_literal: true

require_relative 'option_definition'
require_relative 'run_options'

module ProcessExecuter
  module Options
    # Define options for {ProcessExecuter.run_with_capture}
    #
    # @api public
    #
    class RunWithCaptureOptions < RunOptions
      # The default encoding used for stdout and stderr
      # if no other encoding is specified.
      #
      # @return [Encoding]
      #
      DEFAULT_ENCODING = Encoding::UTF_8

      # Determines the character encoding to use for stdout
      #
      # It prioritizes `stdout_encoding` if set, otherwise falls back to
      # `encoding`, and finally defaults to `DEFAULT_ENCODING` if neither
      # is available.
      #
      # The value is canonicalized to an Encoding object, so equivalent
      # representations (e.g. `Encoding::UTF_8`, `'UTF-8'`, or `:binary` for
      # `Encoding::BINARY`) all resolve to the same Encoding.
      #
      # @return [Encoding, nil] nil if the value names an unknown encoding
      #
      # @api private
      #
      def effective_stdout_encoding
        canonical_encoding(stdout_encoding || encoding || DEFAULT_ENCODING)
      end

      # Determines the character encoding to use for stderr
      #
      # It prioritizes `stderr_encoding` if set, otherwise falls back to
      # `encoding`, and finally defaults to `DEFAULT_ENCODING` if neither
      # is available.
      #
      # The value is canonicalized to an Encoding object, so equivalent
      # representations (e.g. `Encoding::UTF_8`, `'UTF-8'`, or `:binary` for
      # `Encoding::BINARY`) all resolve to the same Encoding.
      #
      # @return [Encoding, nil] nil if the value names an unknown encoding
      #
      # @api private
      #
      def effective_stderr_encoding
        canonical_encoding(stderr_encoding || encoding || DEFAULT_ENCODING)
      end

      private

      # The options allowed for objects of this class
      # @return [Array<OptionDefinition>]
      # @api private
      def define_options
        [
          *super,
          OptionDefinition.new(:merge_output, default: false, validator: method(:validate_merge_output)),
          OptionDefinition.new(:encoding, default: DEFAULT_ENCODING, validator: method(:validate_encoding_option)),
          OptionDefinition.new(:stdout_encoding, default: nil, validator: method(:validate_encoding_option)),
          OptionDefinition.new(:stderr_encoding, default: nil, validator: method(:validate_encoding_option))
        ].freeze
      end

      # Note any errors in the merge_output option
      #
      # Possible errors include:
      # - if the merge_output value is not a Boolean
      # - if merge_output: true and a stderr redirection is given
      # - if merge_output: true and stdout and stderr encodings are different
      # - if a combined stdout/stderr redirection (e.g. `[:out, :err] =>
      #   destination`) is given and stdout and stderr encodings are different
      #
      # @param _key [Symbol] the option key (not used)
      # @param _value [Object] the option value (not used)
      # @return [Void]
      # @api private
      def validate_merge_output(_key, _value)
        unless [true, false].include?(merge_output)
          errors << "merge_output must be true or false but was #{merge_output.inspect}"
        end

        if merge_output == true
          errors << 'Cannot give merge_output: true AND a stderr redirection' if stderr_redirection_source
          validate_uniform_capture_encoding('merge_output: true')
        elsif combined_stdout_and_stderr_redirection?
          validate_uniform_capture_encoding('a redirection that combines stdout and stderr')
        end
      end

      # Note an error if the stdout and stderr encodings are different
      #
      # Used when both streams are captured into the single stdout buffer (via
      # `merge_output: true` or a combined stdout/stderr redirection), which
      # requires a single encoding.
      #
      # Encodings are compared in their canonical form, so equivalent
      # representations (e.g. `Encoding::UTF_8` and `'UTF-8'`) are not
      # rejected. A value that does not canonicalize to an Encoding (an
      # unknown encoding name or an invalid type) is skipped here; the
      # encoding option's own validator reports it.
      #
      # @param description [String] describes the option that requires a single encoding
      # @return [Void]
      # @api private
      def validate_uniform_capture_encoding(description)
        stdout_encoding = effective_stdout_encoding
        stderr_encoding = effective_stderr_encoding

        return unless stdout_encoding.is_a?(Encoding) && stderr_encoding.is_a?(Encoding)
        return if stdout_encoding == stderr_encoding

        errors << "Cannot give #{description} AND give different encodings for stdout and stderr"
      end

      # Convert an encoding option value to its canonical Encoding object
      #
      # @param value [Encoding, String, Symbol, Object] the encoding option value
      #
      # @return [Encoding, Object, nil] the Encoding for a recognized value, nil
      #   for a String naming an unknown encoding, otherwise the value unchanged
      #
      # @api private
      def canonical_encoding(value)
        case value
        when :binary then Encoding::BINARY
        when :default_external then Encoding.default_external
        when String then find_encoding(value)
        else value
        end
      end

      # Find an encoding by name, returning nil if the name is unknown
      #
      # @param name [String] the encoding name
      # @return [Encoding, nil]
      # @api private
      def find_encoding(name)
        Encoding.find(name)
      rescue ::ArgumentError
        nil
      end

      # Note an error if the encoding option is not valid
      # @param key [Symbol] the option key
      # @param value [Object] the option value
      # @return [Void]
      # @api private
      def validate_encoding_option(key, value)
        return unless valid_encoding_type?(key, value)

        return if value.nil? || value.is_a?(Encoding)

        validate_encoding_symbol(key, value) if value.is_a?(Symbol)

        validate_encoding_string(key, value) if value.is_a?(String)
      end

      # False if the value is not a valid encoding type, true otherwise
      #
      # @param key [Symbol] the option key
      #
      # @param value [Object] the option value
      #
      # @return [Boolean]
      #
      # @api private
      #
      def valid_encoding_type?(key, value)
        return true if value.nil? || value.is_a?(Encoding) || value.is_a?(Symbol) || value.is_a?(String)

        errors << "#{key} must be an Encoding object, String, Symbol (:binary, :default_external), " \
                  "or nil, but was #{value.inspect}"

        false
      end

      # Note an error if the encoding symbol is not valid
      #
      # @param key [Symbol] the option key
      #
      # @param value [Symbol] the option value
      #
      # @return [Void]
      #
      # @api private
      #
      def validate_encoding_symbol(key, value)
        return if %i[binary default_external].include?(value)

        errors << "#{key} when given as a symbol must be :binary or :default_external, " \
                  "but was #{value.inspect}"
      end

      # Note an error if the encoding string is not valid
      #
      # @param key [Symbol] the option key
      #
      # @param value [String] the option value
      #
      # @return [void]
      #
      # @api private
      #
      def validate_encoding_string(key, value)
        Encoding.find(value)
      rescue ::ArgumentError
        errors << "#{key} specifies an unknown encoding name: #{value.inspect}"
      end
    end
  end
end
