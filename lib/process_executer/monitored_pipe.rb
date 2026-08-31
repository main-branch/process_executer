# frozen_string_literal: true

require 'stringio'
require 'io/wait'
require 'track_open_instances'

module ProcessExecuter
  # Acts as a pipe that writes the data written to it to one or more destinations
  #
  # {ProcessExecuter::MonitoredPipe} was created to expand the output redirection
  # options for
  # [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
  # and methods derived from it within the `ProcessExecuter` module.
  #
  # This class's initializer accepts any redirection destination supported by
  # [Process.spawn](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn)
  # (this is the `value` part of the file redirection option described in [the File
  # Redirection section of
  # `Process.spawn`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-File+Redirection+-28File+Descriptor-29).
  #
  # In addition to the standard redirection destinations, {ProcessExecuter::MonitoredPipe} also
  # supports these additional types of destinations:
  #
  # - **Arbitrary Writers**
  #
  #   You can redirect subprocess output to any Ruby object that implements the
  #   `#write` method. This is particularly useful for:
  #
  #     - capturing command output in in-memory buffers like `StringIO`
  #     - sending command output to custom logging objects that do not have a file
  #       descriptor
  #     - processing with a streaming parser to parse and process command output as
  #       the command is running
  #
  # - **Multiple Destinations**
  #
  #   MonitoredPipe supports duplicating (or "teeing") output to multiple
  #   destinations simultaneously. This is achieved by providing a redirection
  #   destination in the form `[:tee, destination1, destination2, ...]`, where each
  #   `destination` can be any value that `MonitoredPipe` itself supports (including
  #   another tee or MonitoredPipe).
  #
  # When a new MonitoredPipe is created, a pipe is created (via IO.pipe) and
  # a thread is created to read data written to the pipe. As data is read from the pipe,
  # it is written to the destination provided in the MonitoredPipe initializer.
  #
  # If an exception (of any class, not just `StandardError`) is raised while
  # collecting output -- by the destination's `#write`, by the monitor loop,
  # or by pipe cleanup -- the monitoring thread exits, the pipe is closed, and
  # the exception is saved in {#exception}.
  #
  # > **⚠️ WARNING**
  # >
  # > `#close` must be called to ensure that (1) the pipe is closed, (2) all data is
  #   read from the pipe and written to the destination, and (3) the monitoring thread is
  #   killed.
  #
  # ## File descriptor usage
  #
  # Each MonitoredPipe holds four file descriptors: two for the data pipe the
  # subprocess writes to and two for an internal wake pipe that interrupts the
  # monitoring thread when the pipe is closed. All four are held concurrently
  # from construction until the pipe is closed, so a `ProcessExecuter.run` that
  # captures stdout and stderr holds 8 pipe file descriptors for the duration
  # of the subprocess.
  #
  # File descriptor limits are per-process. An application spawning many
  # commands concurrently can hit the soft `RLIMIT_NOFILE` limit -- macOS
  # defaults to 256 and Linux commonly to 1024. The workaround is to raise the
  # limit in the spawning process, for example with
  # `Process.setrlimit(:NOFILE, 10_240)` or `ulimit -n`.
  #
  # @example Collect pipe data into a StringIO object
  #   pipe_data = StringIO.new
  #   begin
  #     pipe = ProcessExecuter::MonitoredPipe.new(pipe_data)
  #     pipe.write("Hello World")
  #   ensure
  #     pipe.close
  #   end
  #   pipe_data.string #=> "Hello World"
  #
  # @example Collect pipe data into a string AND a file
  #   pipe_data_string = StringIO.new
  #   pipe_data_file = File.open("pipe_data.txt", "w")
  #   begin
  #     pipe = ProcessExecuter::MonitoredPipe.new([:tee, pipe_data_string, pipe_data_file])
  #     pipe.write("Hello World")
  #   ensure
  #     pipe.close
  #   end
  #   pipe_data_string.string #=> "Hello World"
  #   # It is your responsibility to close the file you opened
  #   pipe_data_file.close
  #   File.read("pipe_data.txt") #=> "Hello World"
  #
  # @example Using a MonitoredPipe with Process.spawn
  #   stdout_buffer = StringIO.new
  #   begin
  #     stdout_pipe = ProcessExecuter::MonitoredPipe.new(stdout_buffer)
  #     pid = Process.spawn('echo Hello World', out: stdout_pipe)
  #     _waited_pid, status = Process.wait2(pid)
  #   ensure
  #     stdout_pipe.close
  #   end
  #   stdout_buffer.string #=> "Hello World\n"
  #
  # @api public
  #
  class MonitoredPipe
    include TrackOpenInstances

    # The default number of seconds {#close} waits to drain remaining pipe data
    #
    # Draining normally finishes in well under a second: it only has to read
    # whatever is still buffered in the pipe once every copy of the pipe's
    # write fd is closed. The timeout exists so that a write fd inherited by a
    # process outside this object's control (such as an orphaned descendant of
    # a killed subprocess) cannot make {#close} block indefinitely.
    #
    # @return [Numeric]
    #
    DEFAULT_CLOSE_TIMEOUT = 10

    # Create a new monitored pipe
    #
    # Creates an IO.pipe and starts a monitoring thread to read data written to the
    # pipe.
    #
    # @example
    #   redirection_destination = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(redirection_destination)
    #
    # @param redirection_destination [Object] as data is read from the pipe,
    #   it is written to this destination
    #
    #   Accepts any redirection destination supported by
    #   [`Process.spawn`](https://docs.ruby-lang.org/en/3.4/Process.html#method-c-spawn).
    #   This is the `value` part of the file redirection option described in [the
    #   File Redirection section of
    #   `Process.spawn`](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-File+Redirection+-28File+Descriptor-29).
    #
    #   In addition to the standard redirection destinations, `MonitoredPipe` also
    #   accepts (1) another monitored pipe, (2) any object that implements a `#write` method and
    #   (3) an array in the form `[:tee, destination1, destination2, ...]` where each
    #   `destination` can be any value that `MonitoredPipe` itself supports (including
    #   another tee or MonitoredPipe).
    #
    # @param chunk_size [Integer] the size of the chunks to read from the pipe
    #
    def initialize(redirection_destination, chunk_size: 100_000)
      @destination = Destinations.factory(redirection_destination)
      complete_initialization(chunk_size)
    rescue Exception # rubocop:disable Lint/RescueException
      # The destination may hold resources (e.g. the File opened by
      # Destinations::FilePath), so a failure partway through construction must
      # close whatever was created so far -- the destination and, for each
      # IO.pipe that succeeded, both pipe IOs -- or they leak. A failed
      # initialize never returns a MonitoredPipe instance for the caller (or
      # #close) to clean up.
      [destination, pipe_reader, pipe_writer, wake_reader, wake_writer].each { |resource| resource&.close }
      raise
    end

    # Set the state to `:closing` and wait for the state to be set to `:closed`
    #
    # A byte written to the internal wake pipe interrupts the monitoring
    # thread's wait for pipe data; the thread then sees that the state has
    # changed and closes the pipe.
    #
    # Remaining pipe data is drained to the destination for at most `timeout`
    # seconds. The pipe only reaches EOF once every copy of its write fd is
    # closed -- including copies inherited by processes outside this object's
    # control -- so without a timeout this method could block indefinitely.
    # When the timeout expires before EOF, the pipe is closed anyway,
    # {#truncated?} returns `true`, and data still in the pipe is discarded.
    #
    # The timeout is one absolute deadline for the whole drain: time spent
    # writing to the destination counts against it too. Only the waits for
    # pipe data or EOF are cut short when the deadline passes, though -- a
    # destination `#write` already in progress is never interrupted, so a
    # destination that blocks can still delay this method past the timeout.
    #
    # An exception that escapes the monitoring thread's work is recorded in
    # {#exception} by the monitoring thread itself before it terminates, so the
    # `Thread#join` in this method never re-raises one. An exception raised at
    # the join -- such as an `Interrupt` delivered to the calling thread -- is
    # directed at the caller and propagates.
    #
    # @example
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.state #=> :open
    #   pipe.write('Hello World')
    #   pipe.close
    #   pipe.state #=> :closed
    #   data_collector.string #=> "Hello World"
    #
    # @param timeout [Numeric, nil] the number of seconds to spend draining
    #   remaining pipe data to the destination before giving up, or `nil` to
    #   wait without a time limit. The deadline is absolute -- time in the
    #   destination's `#write` counts against it -- but a write in progress is
    #   never interrupted, so a blocking destination can overrun it.
    #
    # @return [void]
    #
    def close(timeout: DEFAULT_CLOSE_TIMEOUT)
      initiate_close_and_wait_until_closed(timeout)

      thread.join
      destination.close
      self.class.remove_open_instance(self)
    end

    # Return the write end of the pipe so that data can be written to it
    #
    # Data written to this end of the pipe will be read by the monitor thread and
    # written to the destination.
    #
    # This is so we can provide a MonitoredPipe to Process.spawn as a FD
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.to_io.write('Hello World')
    #   pipe.close
    #   data_collector.string #=> "Hello World"
    #
    # @return [IO] the write end of the pipe
    #
    def to_io
      pipe_writer
    end

    # @!attribute [r] fileno
    #
    # The file descriptor for the write end of the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.fileno == pipe.to_io.fileno #=> true
    #
    # @return [Integer] the file descriptor for the write end of the pipe
    #
    def fileno
      pipe_writer.fileno
    end

    # Writes data to the pipe so that it can be read by the monitor thread
    #
    # Primarily used for testing.
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.write('Hello World')
    #   pipe.close
    #   data_collector.string #=> "Hello World"
    #
    # @param data [String] the data to write to the pipe
    #
    # @return [Integer] the number of bytes written to the pipe
    #
    # @raise [IOError] if the pipe is not open
    #
    #   The pipe is only checked before the write begins. If the destination
    #   raises (or another thread calls {#close}) while a large write is still in
    #   progress, the monitoring thread closes the pipe and the in-progress write
    #   fails with an `IOError` too.
    #
    def write(data)
      # The mutex is released before writing to the pipe. `pipe_writer.write`
      # blocks once the OS pipe buffer is full, and it can only be unblocked by
      # the monitoring thread draining the pipe. Holding the mutex across the
      # write would stop the monitoring thread from taking the mutex in its own
      # error path, deadlocking both threads.
      mutex.synchronize { raise IOError, 'closed stream' unless state == :open }

      pipe_writer.write(data)
    rescue SystemCallError
      # Engines disagree about how a write that is already blocked reacts to the
      # monitoring thread closing the pipe. MRI and JRuby raise an IOError.
      # TruffleRuby lets the write continue and fail at the system call, and which
      # errno that is depends on the platform: EPIPE on macOS, EBADF on Linux.
      #
      # The monitoring thread is the only reader of this pipe, so any error from
      # the operating system means the same thing the IOError does: the pipe went
      # away mid-write. Report it as an IOError so #write has one documented
      # contract on every supported engine. The original error is still available
      # through Exception#cause.
      #
      # :nocov: only reached on engines that do not interrupt the blocked write
      raise IOError, 'closed stream'
      # :nocov:
    end

    # @!attribute [r]
    #
    # The size of the chunks to read from the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.chunk_size #=> 100_000
    #
    # @return [Integer] the size of the chunks to read from the pipe
    #
    attr_reader :chunk_size

    # @!attribute [r]
    #
    # The redirection destination to write data that is read from the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.destination #=> #<ProcessExecuter::Destinations::Writer>
    #
    # @return [ProcessExecuter::Destinations::DestinationBase]
    #
    attr_reader :destination

    # @!attribute [r]
    #
    # The state of the pipe
    #
    # Must be either `:open`, `:closing`, or `:closed`
    #
    # * `:open` - the pipe is open and data can be written to it
    # * `:closing` - the pipe is being closed and data can no longer be written to it
    # * `:closed` - the pipe is closed and data can no longer be written to it
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.state #=> :open
    #   pipe.close
    #   pipe.state #=> :closed
    #
    # @return [Symbol] the state of the pipe
    #
    attr_reader :state

    # @!attribute [r]
    #
    # The first exception recorded while collecting output
    #
    # Any failure while collecting output is recorded here, not only a
    # destination error: the destination's `#write` raising, the monitor loop
    # raising, or pipe cleanup raising. `nil` if no exception was raised.
    #
    # When more than one exception is raised, the first one *recorded* wins
    # and the rest are discarded. Recording order has one corner: when the
    # monitor loop raises and pipe cleanup then also raises, the cleanup
    # error is the one recorded, because the monitor-loop exception is still
    # in flight while cleanup runs and reaches its recording site last.
    #
    # @example
    #   pipe.exception #=> nil
    #
    # @return [Exception, nil] the first recorded exception or `nil` if no exception was raised
    #
    attr_reader :exception

    # Whether {#close} gave up draining the pipe before reaching EOF
    #
    # `true` when the close timeout expired before the pipe reached EOF: some
    # copy of the pipe's write fd was still open (for instance, held by an
    # orphaned descendant of a killed subprocess) or unread data remained, and
    # what was left was discarded instead of being written to the destination.
    # An expired timeout on a pipe with nothing left to drain closes normally
    # and stays `false`.
    #
    # @example
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.close
    #   pipe.truncated? #=> false
    #
    # @return [Boolean]
    #
    def truncated? = @truncated

    # @!attribute [r]
    #
    # The thread that monitors the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.thread #=> #<Thread:0x00007f8b1a0b0e00>
    #
    # @return [Thread]
    #
    # @api private
    #
    attr_reader :thread

    # @!attribute [r]
    #
    # The read end of the pipe
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.pipe_reader #=> #<IO:fd 11>
    #
    # @return [IO]
    #
    # @api private
    #
    attr_reader :pipe_reader

    # @!attribute [r]
    #
    # The write end of the pipe
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.pipe_writer #=> #<IO:fd 12>
    #
    # @return [IO] the write end of the pipe
    #
    # @api private
    #
    attr_reader :pipe_writer

    # @!attribute [r]
    #
    # The read end of the internal wake pipe
    #
    # The monitoring thread waits on this IO (along with {#pipe_reader}) so
    # that {#close} can interrupt its wait for pipe data.
    #
    # @return [IO]
    #
    # @api private
    #
    attr_reader :wake_reader

    # @!attribute [r]
    #
    # The write end of the internal wake pipe
    #
    # {#close} writes a single byte to this IO -- at most once in the pipe's
    # life -- to interrupt the monitoring thread's wait for pipe data.
    #
    # @return [IO]
    #
    # @api private
    #
    attr_reader :wake_writer

    private

    # @!attribute [r]
    #
    # The mutex used to synchronize access to the state variable
    #
    # @return [Mutex]
    #
    # @api private
    #
    attr_reader :mutex

    # @!attribute [r]
    #
    # The condition variable used to synchronize access to the state
    #
    # In particular, it is used while waiting for the state to change to :closed
    #
    # @return [ConditionVariable]
    #
    # @api private
    #
    attr_reader :condition_variable

    # Complete construction of the monitored pipe
    #
    # Performs every step of #initialize that can raise after the destination
    # has been created: the compatibility check, creating the data and wake
    # pipes, and starting the monitoring thread. #initialize cleans up the
    # destination and any pipe IOs that were created if any of these steps
    # fail.
    #
    # @param chunk_size [Integer] the size of the chunks to read from the pipe
    # @return [void]
    # @api private
    def complete_initialization(chunk_size)
      assert_destination_is_compatible_with_monitored_pipe

      @mutex = Mutex.new
      @condition_variable = ConditionVariable.new
      @chunk_size = chunk_size

      create_pipes

      @state = :open
      @truncated = false
      @thread = start_monitoring_thread

      self.class.add_open_instance(self)
    end

    # Create the data pipe and the internal wake pipe
    #
    # @return [void]
    # @api private
    def create_pipes
      @pipe_reader, @pipe_writer = IO.pipe

      # Set the encoding of the pipe reader to ASCII_8BIT. This is not strictly
      # necessary since read_nonblock always returns a String where encoding is
      # Encoding::ASCII_8BIT, but it is a good practice to explicitly set the
      # encoding.
      pipe_reader.set_encoding(Encoding::ASCII_8BIT)

      # The wake pipe lets #close interrupt the monitoring thread, which
      # otherwise blocks in IO.select waiting for pipe data (see #monitor_pipe)
      @wake_reader, @wake_writer = IO.pipe
    end

    # Transition the state from `:open` to `:closing` and wait for `:closed`
    #
    # Implements the state-changing half of {#close}: under the mutex, record
    # the close deadline, set the state to `:closing`, wake the monitoring
    # thread, and wait for it to signal that the state reached `:closed`. A
    # pipe that is not `:open` (already closing or closed) is left alone.
    #
    # @param timeout [Numeric, nil] seconds to spend draining remaining pipe
    #   data (see {#close}), or `nil` for no time limit
    # @return [void]
    # @api private
    def initiate_close_and_wait_until_closed(timeout)
      mutex.synchronize do
        break unless state == :open

        @close_deadline = timeout ? Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout : nil
        @state = :closing

        # The wake pipe is written at most once in its life: here, on the
        # :open -> :closing transition. It is a one-shot signal, not a reusable
        # channel, so the monitoring thread never needs to drain it (its loop
        # never continues past this wakeup). The write needs no rescue: the
        # monitoring thread closes the wake fds only after it publishes
        # `@state = :closed` under this same mutex, so while this thread holds
        # the mutex having observed :open, the wake fds are still open.
        wake_writer.write('.')

        condition_variable.wait(mutex) while @state != :closed
      end
    end

    # Raise an error if the destination is not compatible with MonitoredPipe
    # @return [void]
    # @raise [ArgumentError] if the destination is not compatible with MonitoredPipe
    # @api private
    def assert_destination_is_compatible_with_monitored_pipe
      return if destination.compatible_with_monitored_pipe?

      raise ArgumentError, "Destination #{destination.destination} is not compatible with MonitoredPipe"
    end

    # Start the thread to monitor the pipe and write data to the destination
    #
    # An exception that escapes {#monitor} is recorded in {#exception} (unless
    # an exception is already recorded there) so that the thread never
    # terminates holding an unhandled exception.
    #
    # The exception is recorded here, in the monitoring thread itself, rather
    # than by rescuing around the `Thread#join` in {#close}, because a rescue
    # at the join cannot reliably tell the two kinds of exception apart: a
    # monitoring thread exception re-raised by `Thread#join` (which must be
    # recorded) is indistinguishable from an async exception delivered to the
    # calling thread at that same moment -- such as an `Interrupt` from Ctrl-C
    # -- which must propagate. Checking `thread.alive?` in that rescue is racy
    # since the thread can terminate between the exception being raised and
    # the check. Recording at the source removes the ambiguity: the join can
    # never re-raise a monitoring thread exception, so anything raised there
    # is directed at the caller and propagates, while callers like
    # `ProcessExecuter::Commands::Run` read {#exception} and report it as a
    # {ProcessExecuter::ProcessIOError} with the original exception as its
    # cause.
    #
    # @return [void]
    # @api private
    def start_monitoring_thread
      Thread.new do
        Thread.current.report_on_exception = false
        Thread.current.abort_on_exception = false
        begin
          monitor
        rescue Exception => e # rubocop:disable Lint/RescueException
          mutex.synchronize { @exception ||= e }
        end
      end
    end

    # Read data from the pipe until `#state` is changed to `:closing`
    #
    # The state is changed to `:closing` by calling `#close` (or by
    # {#write_data} when the destination raises). The loop reads the state
    # under the mutex: the writers of `@state` hold the mutex, and on engines
    # with real parallelism (JRuby, TruffleRuby) an unsynchronized read has no
    # memory barrier and thus no guarantee of seeing the transition.
    #
    # Before this method returns, state is set to `:closed`. This transition
    # must happen even if closing the pipe raises, or a thread waiting in
    # {#close} would block forever, so any exception raised by `#close_pipe` is
    # saved to {#exception} instead of escaping the `ensure` block.
    #
    # The wake pipe is closed last, after `@state = :closed` is published
    # under the mutex. The loop can also end without ever observing :closing
    # (an exception raised by `#monitor_pipe` while the state is still :open),
    # and in that case a concurrently arriving {#close} may still write the
    # wake byte; this ordering guarantees the wake fds are open whenever
    # {#close} observes :open under the mutex.
    #
    # @return [void]
    # @api private
    def monitor
      monitor_pipe until mutex.synchronize { @state } == :closing
    ensure
      close_pipe_and_record_exception
      mutex.synchronize do
        @state = :closed
        condition_variable.signal
      end
      close_wake_pipe
    end

    # Call `#close_pipe`, saving any exception it raises to {#exception}
    #
    # Rescues `Exception` (not just `StandardError`) so that the `ensure` block
    # in {#monitor} always sets the state to `:closed` and signals the condition
    # variable. The exception is recorded under the same mutex that guards the
    # state transition, and an exception already recorded in {#exception} is not
    # overwritten. This does not interfere with `Thread#kill` or `Thread#exit`,
    # which terminate the thread through a mechanism that `rescue` cannot
    # intercept; only exceptions that would otherwise escape are recorded.
    #
    # @return [void]
    # @api private
    def close_pipe_and_record_exception
      close_pipe
    rescue Exception => e # rubocop:disable Lint/RescueException
      mutex.synchronize { @exception ||= e }
    end

    # Read a chunk of data from the pipe or block until there is one to read
    #
    # Data read from the pipe is written to the destination.
    #
    # When the pipe has no data, block in IO.select (with no timeout, so an
    # idle pipe costs no CPU) until either the pipe has data or {#close}
    # writes its wake byte to the wake pipe. Either way this method returns
    # and {#monitor} re-checks the state before calling it again, so the wake
    # byte is never read: once it is written the state is already :closing and
    # the loop exits.
    #
    # @return [void]
    # @api private
    def monitor_pipe
      # read_nonblock always returns a String where encoding is Encoding::ASCII_8BIT
      new_data = pipe_reader.read_nonblock(chunk_size)
      write_data(new_data)
    rescue IO::WaitReadable
      IO.select([pipe_reader, wake_reader])
    end

    # Write the data read from the pipe to the destination
    #
    # If an exception is raised by a writer, save it to {#exception} and set the
    # state to `:closing` so that the pipe can be closed.
    #
    # Rescues `Exception` (not just `StandardError`) so that a destination
    # raising, for instance, a `NoMemoryError` or a `SignalException` cannot
    # kill the monitoring thread and leave {#close} blocked forever.
    #
    # Unlike {#close}, this error path needs no wake byte: it runs on the
    # monitoring thread itself, and {#monitor}'s loop re-checks the state as
    # soon as this method returns.
    #
    # @param data [String] the data read from the pipe
    # @return [void]
    # @api private
    def write_data(data)
      destination.write(data)
    rescue Exception => e # rubocop:disable Lint/RescueException
      mutex.synchronize do
        @exception = e
        @state = :closing
      end
    end

    # Read any remaining data from the pipe and close it
    #
    # @return [void]
    # @api private
    def close_pipe
      # Close the write end of the pipe so no more data can be written to it
      pipe_writer.close

      # Read remaining data from pipe_reader (if any)
      # If an exception was already raised by the last call to #write, then don't try to read remaining data
      drain_pipe

      # Close the read end of the pipe
      pipe_reader.close
    end

    # Read remaining pipe data to the destination until EOF or the close deadline
    #
    # The pipe reaches EOF only once every copy of the write fd is closed,
    # including copies inherited by processes this object knows nothing about
    # (such as orphaned descendants of a killed subprocess). The deadline set
    # by {#close} bounds the wait on such an fd: when it passes before EOF,
    # draining stops and {#truncated?} becomes true. A `nil` deadline (a
    # `close(timeout: nil)`, or the monitoring thread closing the pipe on its
    # own after a destination exception) means no time limit.
    #
    # EOF is probed before the deadline is applied so that a pipe with nothing
    # left to drain closes normally -- not as truncated -- even when the
    # deadline has already passed (such as a `close(timeout: 0)`). Truncation
    # is recorded only when the expired deadline abandons unread data or a
    # still-open write fd.
    #
    # There is no need to poll: nothing outside this loop can end it, so each
    # wait sleeps until the pipe has data or reaches EOF (both wake
    # `wait_readable`), bounded by the time remaining before the deadline.
    #
    # The deadline bounds only the waits for pipe data or EOF. A call to
    # {#write_data} runs the destination's `#write`, which is arbitrary user
    # code that cannot safely be interrupted, so a destination that blocks can
    # still hold this loop past the deadline; the deadline is applied again as
    # soon as the write returns.
    #
    # @return [void]
    # @api private
    def drain_pipe
      while exception.nil?
        remaining_time = time_remaining_until_close_deadline

        data = pipe_reader.read_nonblock(chunk_size, exception: false)

        break if data.nil? # EOF: every copy of the pipe's write fd is closed

        if remaining_time&.zero?
          @truncated = true
          break
        end

        data == :wait_readable ? pipe_reader.wait_readable(remaining_time) : write_data(data)
      end
    end

    # Close both ends of the internal wake pipe
    #
    # Called from {#monitor}'s `ensure` block after `@state = :closed` is
    # published, on every teardown path (a normal {#close}, a destination
    # error, or an exception that ends the monitor loop). The `closed?` guards
    # make it safe when a test helper has already closed the fds after killing
    # the monitoring thread.
    #
    # @return [void]
    # @api private
    def close_wake_pipe
      wake_writer.close unless wake_writer.closed?
      wake_reader.close unless wake_reader.closed?
    end

    # The seconds left before the deadline set by {#close}
    #
    # @return [Numeric, nil] `nil` when no deadline is set (wait without a
    #   time limit), 0 when the deadline has passed
    # @api private
    def time_remaining_until_close_deadline
      return nil if @close_deadline.nil?

      [@close_deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max
    end
  end
end
