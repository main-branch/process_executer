# frozen_string_literal: true

module ProcessExecuter
  # A replacement for Process::Status that can be used to mock the exit status of a process
  #
  # This class is not currently used in this Gem.
  #
  # Process::Status encapsulates the information on the status of a running or
  # terminated system process. The built-in variable $? is either nil or a
  # Process::Status object.
  #
  # ```ruby
  # fork { exit 99 }   #=> 26557
  # Process.wait       #=> 26557
  # $?.class           #=> Process::Status
  # $?.to_i            #=> 25344
  # $? >> 8            #=> 99
  # $?.stopped?        #=> false
  # $?.exited?         #=> true
  # $?.exitstatus      #=> 99
  # ```
  #
  # Posix systems record information on processes using a 16-bit integer. The
  # lower bits record the process status (stopped, exited, signaled) and the
  # upper bits possibly contain additional information (for example the program's
  # return code in the case of exited processes). Pre Ruby 1.8, these bits were
  # exposed directly to the Ruby program. Ruby now encapsulates these in a
  # Process::Status object. To maximize compatibility, however, these objects
  # retain a bit-oriented interface. In the descriptions that follow, when we
  # talk about the integer value of stat, we're referring to this 16 bit value.
  #
  # @api public
  #
  class Status
    # Create a new Status object
    #
    # @example
    #   status = ProcessExecuter::Status.new(999, 0)
    #   status.exited? # => true
    #   status.success? # => true
    #   status.exitstatus # => 0
    #
    def initialize(pid, stat)
      @pid = pid
      @stat = stat
    end

    # @!attribute
    #
    # The pid of the process
    #
    # @example
    #   status = ProcessExecuter::Status.new(999, 0)
    #   status.pid # => 999
    #
    # @return [Integer]
    #
    # @api public
    #
    attr_reader :pid

    # @!attribute
    #
    # The status code of the process
    #
    # @example
    #   status = ProcessExecuter::Status.new(999, 123)
    #   status.stat # => 123
    #
    # @return [Integer]
    #
    # @api public
    #
    attr_reader :stat

    # Logical AND of the bits in stat with `other`
    #
    # @example Process ended due to an uncaught signal 11 with a core dump
    #   status = ProcessExecuter::Status.new(999, 139)
    #   status & 127 # => 11 => the uncaught signal
    #   !(status & 128).zero? # => true => indicating a core dump
    #
    # @param other [Integer] the value to AND with stat
    #
    # @return [Integer] the result of the AND operation
    #
    def &(other)
      stat & other
    end

    # Compare stat to `other`
    #
    # @example Process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status == 25_344 # => true
    #
    # @param other [Integer] the value to compare stat to
    #
    # @return [Boolean] true if stat == other, false otherwise
    #
    def ==(other)
      stat == other
    end

    # rubocop:disable Naming/BinaryOperatorParameterName

    # Shift the bits in stat right `num` places
    #
    # @example Process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status >> 8 # => 99
    #
    # @param num [Integer] the number of places to shift stat
    #
    # @return [Integer] the result of the shift operation
    #
    def >>(num)
      stat >> num
    end

    # rubocop:enable Naming/BinaryOperatorParameterName

    # Returns true if the process generated a coredump upon termination
    #
    # Not available on all platforms.
    #
    # @example process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status.coredump? # => false
    #
    # @example process ended due to an uncaught signal 11 with a core dump
    #   status = ProcessExecuter::Status.new(999, 139)
    #   status.coredump? # => true
    #
    # @return [Boolean] true if stat generated a coredump when it terminated
    #
    def coredump?
      !(stat & 128).zero?
    end

    # Returns true if the process exited normally
    #
    # This happens when the process uses an exit() call or runs to the end of the program.
    #
    # @example process exited normally with exitstatus 0
    #   status = ProcessExecuter::Status.new(999, 0)
    #   status.exited? # => true
    #
    # @example process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status.exited? # => true
    #
    # @example process ended due to an uncaught signal 11 with a core dump
    #   status = ProcessExecuter::Status.new(999, 139)
    #   status.exited? # => false
    #
    # @return [Boolean] true if the process exited normally
    #
    def exited?
      (stat & 127).zero?
    end

    # Returns the exit status of the process
    #
    # Returns nil if the process did not exit normally (when `#exited?` is false).
    #
    # @example process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status.exitstatus # => 99
    #
    # @return [Integer, nil] the exit status of the process
    #
    def exitstatus
      stat >> 8 if exited?
    end

    # Returns true if the process was successful
    #
    # This means that `exited?` is true and `#exitstatus` is 0.
    #
    # Returns nil if the process did not exit normally (when `#exited?` is false).
    #
    # @example process exited normally with exitstatus 0
    #   status = ProcessExecuter::Status.new(999, 0)
    #   status.success? # => true
    #
    # @example process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status.success? # => false
    #
    # @example process ended due to an uncaught signal 11 with a core dump
    #   status = ProcessExecuter::Status.new(999, 139)
    #   status.success? # => nil
    #
    # @return [Boolean, nil] true if successful, false if unsuccessful, nil if the process did not exit normally
    #
    def success?
      exitstatus.zero? if exited?
    end

    # Returns true if the process was stopped
    #
    # @example with a stopped process with signal 17
    #   status = ProcessExecuter::Status.new(999, 4_479)
    #   status.stopped? # => true
    #
    # @example process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status.stopped? # => false
    #
    # @example process ended due to an uncaught signal 11 with a core dump
    #   status = ProcessExecuter::Status.new(999, 139)
    #   status.stopped? # => false
    #
    # @return [Boolean] true if the process was stopped, false otherwise
    #
    def stopped?
      (stat & 127) == 127
    end

    # The signal number that casused the process to stop
    #
    # Returns nil if the process is not stopped.
    #
    # @example with a stopped process with signal 17
    #   status = ProcessExecuter::Status.new(999, 4_479)
    #   status.stopsig # => 17
    #
    # @example process exited normally with exitstatus 99
    #   status = ProcessExecuter::Status.new(999, 25_344)
    #   status.stopsig # => nil
    #
    # @return [Integer, nil] the signal number that caused the process to stop or nil
    #
    def stopsig
      stat >> 8 if stopped?
    end

    # Returns true if stat terminated because of an uncaught signal
    #
    # @example process ended due to an uncaught signal 9
    #   status = ProcessExecuter::Status.new(999, 9)
    #   status.signaled? # => true
    #
    # @example process exited normally with exitstatus 0
    #   status = ProcessExecuter::Status.new(999, 0)
    #   status.signaled? # => false
    #
    # @return [Boolean] true if stat terminated because of an uncaught signal, false otherwise
    #
    def signaled?
      ![0, 127].include?(stat & 127)
    end

    # Returns the number of the signal that caused the process to terminate
    #
    # Returns nil if the process exited normally or is stopped.
    #
    # @example process ended due to an uncaught signal 9
    #   status = ProcessExecuter::Status.new(999, 9)
    #   status.termsig # => 9
    #
    # @example process exited normally with exitstatus 0
    #   status = ProcessExecuter::Status.new(999, 0)
    #   status.termsig # => nil
    #
    # @return [Integer, nil] the signal number that caused the process to terminate or nil
    #
    def termsig
      stat & 127 if signaled?
    end

    # Returns the bits in stat as an Integer
    #
    # @example with a stopped process with signal 17
    #   status = ProcessExecuter::Status.new(999, 4_479)
    #   status.to_i # => 4_479
    #
    # @return [Integer] the bits in stat
    #
    def to_i
      stat
    end

    # Show the status type, pid, and exit status as a string
    #
    # @example with a stopped process with signal 17
    #   status = ProcessExecuter::Status.new(999, 4_479)
    #   status.to_s # => "pid 999 stopped SIGSTOP (signal 17)"
    #
    # @return [String] the status type, pid, and exit status as a string
    #
    def to_s
      type_to_s + (coredump? ? ' (core dumped)' : '')
    end

    # Show the status type, pid, and exit status as a string
    #
    # @example with a stopped process with signal 17
    #   status = ProcessExecuter::Status.new(999, 4_479)
    #   status.inspect # => "#<ProcessExecuter::Status pid 999 stopped SIGSTOP (signal 17)>"
    #
    # @return [String] the status type, pid, and exit status as a string
    #
    def inspect
      "#<#{self.class} #{self}>"
    end

    private

    # The string representation of a status based on how it was terminated
    # @return [String] the string representation
    # @api private
    def type_to_s
      if signaled?
        signaled_to_s
      elsif exited?
        exited_to_s
      elsif stopped?
        stopped_to_s
      end
    end

    # The string representation of a signaled process
    # @return [String] the string representation of a signaled process
    # @api private
    def signaled_to_s
      "pid #{pid} SIG#{signame(termsig)} (signal #{termsig})"
    end

    # The string representation of an exited process
    # @return [String] the string representation of an exited process
    # @api private
    def exited_to_s
      "pid #{pid} exit #{exitstatus}"
    end

    # The string representation of a stopped process
    # @return [String] the string representation of a stopped process
    # @api private
    def stopped_to_s
      "pid #{pid} stopped SIG#{signame(stopsig)} (signal #{stopsig})"
    end

    # The name of the signal or 'UNKNOWN' if the signal is not known
    #
    # On MRI on Mac, `Signal.signame` returns `nil` for unknown signals.
    #
    # On JRuby on Windows, `Signal.signame` raises an ArgumentError for unknown signals.
    #
    # @param [Integer] signal the signal number
    #
    # @return [String] the name of the signal or 'UNKNOWN'
    #
    # @api private
    #
    def signame(sig)
      raise ArgumentError if Signal.signame(sig).nil?

      Signal.signame(sig)
    rescue ArgumentError
      'UNKNOWN'
    end
  end
end
