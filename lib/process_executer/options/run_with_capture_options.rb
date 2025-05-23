# frozen_string_literal: true

require_relative 'option_definition'
require_relative 'run_options'

module ProcessExecuter
  module Options
    # Define options for the `ProcessExecuter.run`
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

      # Validate the merge_output option value
      # @return [String, nil] the error message if the value is not valid
      # @api private
      def validate_merge_output
        if [true, false].include?(merge_output)
          if merge_output == true && stderr_redirection_key
            errors << 'Can not give merge_output: true AND give a stderr redirection'
          end
        else
          errors << "merge_output must be true or false but was #{merge_output.inspect}"
        end
      end
    end
  end
end
