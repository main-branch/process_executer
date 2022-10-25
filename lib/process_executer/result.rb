# frozen_string_literal: true

class ProcessExecuter
  # The result of executing a command
  #
  # @api public
  #
  class Result
    # The status of the command process
    #
    # @example
    #   status # => #<Process::Status: pid 86235 exit 0>
    #   out = 'hello'
    #   err = 'ERROR'
    #   command = ProcessExecuter.new(status, out, err)
    #   command.status # => #<Process::Status: pid 86235 exit 0>
    #
    # @return [Process::Status]
    #
    attr_reader :status

    # The command's stdout (if collected)
    #
    # @example
    #   status # => #<Process::Status: pid 86235 exit 0>
    #   out = 'hello'
    #   err = 'ERROR'
    #   command = ProcessExecuter.new(status, out, err)
    #   command.out # => "hello\n"
    #
    # @return [String, nil]
    #
    attr_reader :out

    # The command's stderr (if collected)
    #
    # @example
    #   status # => #<Process::Status: pid 86235 exit 0>
    #   out = 'hello'
    #   err = 'ERROR'
    #   command = ProcessExecuter.new(status, out, err)
    #   command.out # => "ERROR\n"
    #
    # @return [String, nil]
    #
    attr_reader :err

    # Create a new Result object
    #
    # @example
    #   status # => #<Process::Status: pid 86235 exit 0>
    #   out = 'hello'
    #   err = 'ERROR'
    #   command = ProcessExecuter.new(status, out, err)
    #
    # @param status [Process::Status] the status of the command process
    # @param out [String, nil] the command's stdout (if collected)
    # @param err [String, nil] the command's stderr (if collected)
    #
    # @return [ProcessExecuter::Result] the result object
    #
    def initialize(status, out, err)
      @status = status
      @out = out
      @err = err
    end
  end
end
