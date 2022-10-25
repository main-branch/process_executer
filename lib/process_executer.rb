# frozen_string_literal: true

# rubocop:disable Style/SingleLineMethods

require 'process_executer/result'
# require 'nio'

# Execute a process and capture the output to a string, a file, and/or
# pass the output through to this process's stdout/stderr.
#
# @api public
#
class ProcessExecuter
  # stdout collected from the command
  #
  # @example
  #   command = ProcessExecuter.new
  #   command.execute('echo hello')
  #   command.out # => "hello\n"
  #
  # @return [String, nil] nil if collect_out? is false
  #
  attr_reader :out

  # stderr collected from the command
  #
  # @example
  #   command = ProcessExecuter.new
  #   command.execute('echo hello 1>&2')
  #   command.err # => "hello\n"
  #
  # @return [String, nil] nil if collect_err? is false
  #
  attr_reader :err

  # The status of the command process
  #
  # Will be `nil` if the command has not completed execution.
  #
  # @example
  #   command = ProcessExecuter.new
  #   command.execute('echo hello')
  #   command.status # => #<Process::Status: pid 86235 exit 0>
  #
  # @return [Process::Status, nil]
  #
  attr_reader :status

  # Show the command's stdout on this process's stdout
  #
  # @example
  #   command = ProcessExecuter.new(passthru_out: true)
  #   command.passthru_out? # => true
  #
  # @return [Boolean]
  #
  def passthru_out?; !!@passthru_out; end

  # Show the command's stderr on this process's stderr
  #
  # @example
  #   command = ProcessExecuter.new(passthru_err: true)
  #   command.passthru_err? # => true
  #
  # @return [Boolean]
  #
  def passthru_err?; !!@passthru_err; end

  # Collect the command's stdout the :out string (default is true)
  #
  # @example
  #   command = ProcessExecuter.new(collect_out: false)
  #   command.collect_out? # => false
  #
  # @return [Boolean]
  #
  def collect_out?; !!@collect_out; end

  # Collect the command's stderr the :err string (default is true)
  #
  # @example
  #   command = ProcessExecuter.new(collect_err: false)
  #   command.collect_err? # => false
  #
  # @return [Boolean]
  #
  def collect_err?; !!@collect_err; end

  # Create a new ProcessExecuter
  #
  # @example
  #   command = ProcessExecuter.new(passthru_out: false, passthru_err: false)
  #
  # @param passthru_out [Boolean] show the command's stdout on this process's stdout
  # @param passthru_err [Boolean] show the command's stderr on this process's stderr
  # @param collect_out [Boolean] collect the command's stdout the :out string
  # @param collect_err [Boolean] collect the command's stderr the :err string
  #
  def initialize(passthru_out: false, passthru_err: false, collect_out: true, collect_err: true)
    @passthru_out = passthru_out
    @passthru_err = passthru_err
    @collect_out = collect_out
    @collect_err = collect_err
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength

  # Execute the given command in a subprocess
  #
  # See Process.spawn for acceptable values for command and options.
  #
  # Do no specify the following options: :in, :out, :err, integer, #fileno, :close_others.
  #
  # @example Execute a command as a single string
  #   result = ProcessExecuter.new.execute('echo hello')
  #
  # @example Execute a command as with each argument as a separate string
  #  result = ProcessExecuter.new.execute('echo', 'hello')
  #
  # @example Execute a command in a specific directory
  #  result = ProcessExecuter.new.execute('pwd', chdir: '/tmp')
  #  result.out # => "/tmp\n"
  #
  # @example Execute a command with specific environment variables
  #  result = ProcessExecuter.new.execute({ 'FOO' => 'bar' }, 'echo $FOO' )
  #  result.out # => "bar\n"
  #
  # @param command [String, Array<String>] the command to pass to Process.spawn
  # @param options [Hash] options to pass to Process.spawn
  #
  # @return [ProcessExecuter::Result] the result of the command execution
  #
  def execute(*command, **options)
    @status = nil
    @out = (collect_out? ? '' : nil)
    @err = (collect_err? ? '' : nil)

    out_reader, out_writer = IO.pipe
    err_reader, err_writer = IO.pipe

    options[:out] = out_writer
    options[:err] = err_writer

    pid = Process.spawn(*command, options)

    loop do
      read_command_output(out_reader, err_reader)

      _pid, @status = Process.wait2(pid, Process::WNOHANG)
      break if @status

      # puts "finished_pid: #{finished_pid}"
      # puts "status: #{status}"

      # puts 'starting select'
      # readers, writers, exceptions = IO.select([stdout_reader, stderr_reader], nil, nil, 0.1)
      IO.select([out_reader, err_reader], nil, nil, 0.05)

      # puts "readers: #{readers}"
      # puts "writers: #{writers}"
      # puts "exceptions: #{exceptions}"

      # break unless readers || writers || exceptions

      _pid, @status = Process.wait2(pid, Process::WNOHANG)
      break if @status

      # puts "finished_pid: #{finished_pid}"
      # puts "status: #{status}"
    end

    out_writer.close
    err_writer.close

    # Read whatever is left over after the process terminates
    read_command_output(out_reader, err_reader)
    ProcessExecuter::Result.new(@status, @out, @err)
  end

  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  private

  # Read output from the given readers
  # @return [void]
  # @api private
  def read_command_output(out_reader, err_reader)
    loop do
      # Keep reading until there is nothing left to read
      break unless read_out(out_reader) || read_err(err_reader)
    end
  end

  # Read stdout from the given reader
  # @return [void]
  # @api private
  def read_out(reader)
    new_data = reader.read_nonblock(1024)
    # puts "new_stdout: '#{new_data}'"
    @out += new_data if new_data && collect_out?
    puts new_data if new_data && passthru_out?
    true
  rescue EOFError, IO::EAGAINWaitReadable
    # Nothing to read at this time
    false
  end

  # Read stderr from the given reader
  # @return [void]
  # @api private
  def read_err(reader)
    new_data = reader.read_nonblock(1024)
    # puts "new_stderr: '#{new_data}'"
    @err += new_data if new_data && collect_err?
    warn new_data if new_data && passthru_err?
    true
  rescue EOFError, IO::EAGAINWaitReadable
    # Nothing to read at this time
    false
  end
end

# rubocop:enable Style/SingleLineMethods
