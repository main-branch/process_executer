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
      private

      # The options allowed for objects of this class
      # @return [Array<OptionDefinition>]
      # @api private
      def define_options
        [
          *super,
          OptionDefinition.new(:merge_output, default: false, validator: method(:validate_merge_output))
        ].freeze
      end

      # Note an error if merge_output is not true or false
      # @param _key [Symbol] the option key (not used)
      # @param _value [Object] the option value (not used)
      # @return [Void]
      # @api private
      def validate_merge_output(_key, _value)
        if [true, false].include?(merge_output)
          if merge_output == true && stderr_redirection_source
            errors << 'Cannot give merge_output: true AND give a stderr redirection'
          end
        else
          errors << "merge_output must be true or false but was #{merge_output.inspect}"
        end
      end
    end
  end
end
