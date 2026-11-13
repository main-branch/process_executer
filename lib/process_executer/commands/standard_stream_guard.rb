# frozen_string_literal: true

require 'monitor'

module ProcessExecuter
  module Commands
    # Puts stdout and stderr back after a failed spawn left them pointed at pipes
    #
    # A workaround for [Ruby Bug #22540](https://bugs.ruby-lang.org/issues/22540),
    # used only on Windows MRI. There, `Process.spawn` points this process's
    # stdout and stderr at the redirection targets before it spawns and doesn't
    # point them back when a later option fails, such as a `chdir:` the process
    # can't enter. When the targets are {MonitoredPipe}s that {Run} attached, the
    # caller is left writing into pipes nobody reads -- something
    # `Process.spawn` given the caller's own options would not have done.
    #
    # {#call} copies descriptors 1 and 2, runs the spawn, and after a spawn that
    # doesn't return, points the descriptors back at the copies -- but only when
    # the pipes show that they leaked. A restore after every failed spawn would
    # disturb other threads for failures that leak nothing: on Ruby 3.1 through
    # 3.4, reopening descriptor 1 or 2 raises `IOError` in any thread that is
    # writing to it.
    #
    # What this class does not repair:
    #
    # * Env, umask, and stdin. They leak the same way through `Process.spawn`,
    #   so this gem leaves the caller no worse off than `Process.spawn` does.
    # * Ruby's descriptor leak. Each spawn that fails this way leaves open the
    #   two copies Ruby itself made of the descriptors it redirected, and Ruby
    #   code can't find them to close them. After about 4,090 such failures the
    #   process is out of descriptors and every later call that attaches a pipe
    #   raises {ProcessExecuter::SpawnError} (`Too many open files`) at once;
    #   stdout and stderr still work.
    # * A thread writing to stdout or stderr while a leak is repaired. It gets
    #   an `Errno::EPIPE` from the pipe whose reader the leak check closed, and
    #   on Ruby 3.1 through 3.4 an `IOError` from the reopen. Without the repair
    #   every later write fails.
    # * A stream the caller closed before the call. There is no copy to put
    #   back, so a leaked descriptor stays pointed at the pipe and closing the
    #   pipes waits out {MonitoredPipe::DEFAULT_CLOSE_TIMEOUT}.
    #
    # ## Operations this class avoids
    #
    # While a descriptor is leaked, another thread may be writing to stdout or
    # stderr. Ruby writes to descriptors 1 and 2 with a synchronous call, but
    # the pipe they now point at was opened for overlapped I/O, and on such a
    # handle a synchronous write that has to wait can miss its completion when
    # any other operation touches the same pipe end. The writer then waits
    # forever holding the C runtime's lock on the descriptor, and the next
    # thread to use that descriptor while holding the GVL stops the process.
    # That is a Ruby bug of its own, tracked in
    # [issue 210](https://github.com/main-branch/process_executer/issues/210).
    #
    # Two things Ruby does are such operations, so nothing here does either to
    # a pipe end or to a standard stream:
    #
    # * `IO#close`, which calls `UnlockFile` on the handle. A descriptor is
    #   pointed at the null device with `IO#reopen` first, which swaps the
    #   handle under the C runtime's lock, and then closed. That goes for the
    #   copies of the standard streams and for each pipe's own write end.
    # * `IO.for_fd`, which queries the handle. Copies are made with `IO#dup`,
    #   and the two IO objects a restore reopens are made once per process,
    #   before any spawn.
    #
    # The code this leads to looks roundabout, and the direct form of each step
    # (`copy.close`, `IO.for_fd(fd)`, `STDOUT.reopen`) passes every example.
    # No example can show the difference: the hang is a race with no
    # deterministic trigger. Before simplifying anything here, run the script
    # in issue 210 against the change. Code outside this class that closes,
    # stats, or wraps a standard descriptor while one is leaked can still
    # trigger the hang.
    #
    # Remove this class, and its use in {Run}, when the gem's minimum supported
    # Ruby is a release line in which every patch version has the fix for Ruby
    # Bug #22540. Until then, once the fixed versions are known, gate its use on
    # `RUBY_VERSION` so a fixed Ruby doesn't pay for the copies and the lock.
    #
    # @api private
    #
    class StandardStreamGuard
      # Serializes the save, the spawn, and the restore across threads
      #
      # Without it, one thread can save descriptors that another thread's
      # failed spawn has just leaked, and then restore the leak.
      #
      # A Monitor, not a Mutex, so the thread that holds it can enter again:
      # `Process.spawn` calls coercion methods such as an env value's
      # `#to_str` inside the lock, and one of those may itself run a command
      # through this class.
      #
      # @return [Monitor]
      #
      LOCK = Monitor.new

      # The descriptors to guard and the IO objects that own them
      #
      # The constants and not `$stdout` and `$stderr`: a caller can point the
      # globals at a `StringIO`, and the leak is in descriptors 1 and 2.
      #
      # @return [Hash{Integer => IO}]
      #
      STREAMS = { 1 => STDOUT, 2 => STDERR }.freeze # rubocop:disable Style/GlobalStdStream

      # :nocov: the rest of this class runs only on Windows MRI

      # Create a guard for a spawn that redirects to the given pipes
      #
      # @example
      #   pipes = { out: ProcessExecuter::MonitoredPipe.new(StringIO.new) }
      #   guard = ProcessExecuter::Commands::StandardStreamGuard.new(pipes)
      #
      # @param pipes [Hash{Object => ProcessExecuter::MonitoredPipe}] the pipes
      #   the spawn redirects stdout and stderr to
      #
      def initialize(pipes)
        @pipes = pipes
        @pipes_closed = false
      end

      # Whether {#call} closed the pipes while checking them for a leak
      #
      # True after a spawn that didn't return: the leak check has to close every
      # pipe to see whether it reaches end-of-file, so the owner of the pipes
      # must not close them again or report what the check left in them.
      #
      # @example
      #   guard.pipes_closed? #=> false
      #
      # @return [Boolean]
      #
      def pipes_closed? = @pipes_closed

      # Run the spawn in the block, undoing a stdout or stderr leak if it is unwound
      #
      # The block can be left by an exception of any class or by a `throw`; the
      # leak is checked for and undone in each case.
      #
      # Exceptions raised from other threads are deferred for the length of the
      # block (one spawn). One that landed between the failed spawn and the
      # restore would leave the leak in place and then close the copies the
      # restore needed. A deferred exception is delivered as this method
      # returns, including after a spawn that succeeded, so the block must
      # record the pid itself for the caller to know a subprocess is running.
      # The mask is on `Object`, not `Exception`, so that it also defers
      # `Thread#kill`, which is not delivered as an exception.
      #
      # A signal handler is not deferred: it runs on the main thread whenever
      # the signal arrives, and may raise or throw there. So the check and the
      # restore are started again, from an `ensure`, each time they are unwound
      # before they finish; what unwound them carries on once they are done.
      #
      # @example
      #   pid = guard.call { Process.spawn('echo hello', out: pipes[:out]) }
      #
      # @yield the call to `Process.spawn`
      #
      # @return [Object] the value of the block
      #
      # @raise [Exception] whatever the block raised
      #
      def call(&spawn)
        LOCK.synchronize do
          Thread.handle_interrupt(Object => :never) { spawn_and_repair(save, &spawn) }
        end
      end

      private

      # The pipes the spawn redirects stdout and stderr to
      #
      # @return [Hash{Object => ProcessExecuter::MonitoredPipe}]
      #
      attr_reader :pipes

      # Run the spawn, restore the saved descriptors if it leaked, and close the copies
      #
      # A flag and an `ensure`, not a `rescue`: a `throw` or a `Thread#kill`
      # leaves the block without raising anything a `rescue` could see.
      #
      # @param copies [Hash{Integer => IO}] each descriptor and its copy
      #
      # @yield the call to `Process.spawn`
      #
      # @return [Object] the value of the block
      #
      def spawn_and_repair(copies)
        completed = false
        result = yield
        completed = true
        result
      ensure
        completed ? release(copies) : repair_and_release(copies)
      end

      # Restore the saved descriptors if the spawn leaked, then close the copies
      #
      # Starts again if it is unwound before it finishes, which a signal
      # handler that raises or throws can do at any point. Every step can be
      # repeated: closing a closed pipe and pointing a descriptor at its copy
      # a second time change nothing.
      #
      # The leak check comes before the restore, and must: it closes each
      # pipe's reader, which makes a write another thread has in progress on a
      # leaked descriptor fail. Restoring first would wait for such a write
      # with the GVL held, while the thread that could let it finish by
      # reading the pipe waits for the GVL.
      #
      # An error from the restore or from closing a copy is raised without
      # starting again, since a second try would fail the same way.
      #
      # @param copies [Hash{Integer => IO}] each descriptor and its copy
      #
      # @return [void]
      #
      def repair_and_release(copies)
        restore(copies) if leaked?
        release(copies)
        finished = true
      rescue IOError, SystemCallError
        finished = true
        release(copies)
        raise
      ensure
        repair_and_release(copies) unless finished
      end

      # Close the copies of descriptors 1 and 2
      #
      # Each copy is taken out of the hash before it is closed, so that a call
      # repeated after an interruption never closes a copy twice.
      #
      # @param copies [Hash{Integer => IO}] each descriptor and its copy
      #
      # @return [void]
      #
      def release(copies)
        until copies.empty?
          _fd, copy = copies.shift
          discard(copy)
        end
      end

      # Close a copy of a standard stream without touching the stream itself
      #
      # The copy is pointed at the null device before it is closed. Ruby's close
      # on Windows calls `UnlockFile` on the handle, and the copy and the stream
      # are the same open file; see "Operations this class avoids" in the class
      # comment. Both lines are needed: `copy.close` alone is the call to avoid.
      #
      # @param copy [IO] a copy made by {#copy_of}
      #
      # @return [void]
      #
      def discard(copy)
        copy.reopen(self.class.null_device)
        copy.close
      end

      # Copy descriptors 1 and 2 so they can be put back
      #
      # A stream the caller closed has no copy. When the process is out of
      # descriptors the result holds whatever was copied before that.
      #
      # @return [Hash{Integer => IO}] each descriptor and its copy
      #
      def save
        copies = {}
        STREAMS.each do |fd, io|
          next if io.closed?

          # The result is not used here. The call makes the object {#restore}
          # will need, now, while the descriptor is not leaked.
          self.class.target(fd)
          copies[fd] = copy_of(io)
        end
        copies
      rescue SystemCallError
        copies
      end

      # Copy a standard stream to a descriptor above 2
      #
      # A copy that lands on 0, 1 or 2 (the caller closed one of them) could be
      # overwritten by the spawn's own redirections, so it is held open until a
      # higher one is made.
      #
      # `IO#dup` and not `fcntl(F_DUPFD, 3)`, which would do this in one step:
      # the descriptor number it returns needs `IO.for_fd` to become an IO.
      #
      # @param io [IO] STDOUT or STDERR
      #
      # @return [IO] the copy
      #
      def copy_of(io)
        copy = io.dup
        return copy if copy.fileno > 2

        begin
          copy_of(io)
        ensure
          discard(copy)
        end
      end

      # Whether the failed spawn left a descriptor pointed at one of the pipes
      #
      # The spawn failed, so there is no subprocess: once a pipe's own write
      # end is closed, only a leaked descriptor in this process can keep the
      # pipe from reaching end-of-file. Closing with a zero timeout reads the
      # pipe once and reports anything short of end-of-file as truncated.
      #
      # A signal handler can also unwind the block just after a spawn that
      # succeeded. The subprocess then holds the pipes open and this reports a
      # leak that isn't there; the restore that follows points each descriptor
      # at a copy of itself, which changes nothing.
      #
      # A pipe whose destination raised on a write also counts as leaked. With
      # no subprocess the data it was writing can only have come through a
      # leaked descriptor; after such an error the pipe stops reading, so it
      # never reports itself truncated.
      #
      # The pipe is asked whether its destination failed, not whether it
      # recorded an exception. {#close_pipe} takes the pipe's own write end
      # away before closing the pipe, and when nothing leaked the reading
      # thread can reach end-of-file in between and record an `EOFError`. A
      # destination can raise that class too, so the class can't tell them
      # apart.
      #
      # @return [Boolean]
      #
      def leaked?
        pipes.each_value { |pipe| close_pipe(pipe) }
        @pipes_closed = true
        pipes.each_value.any? { |pipe| pipe.truncated? || pipe.destination_failed? }
      end

      # Close a pipe for the leak check, ignoring an error from the close
      #
      # The pipe's write end is pointed at the null device first, so that the
      # close the pipe then does on it never reaches the pipe; see "Operations
      # this class avoids" in the class comment. No other thread can be using
      # that descriptor: {Run} made the pipe for this one spawn.
      #
      # This step can't move into {MonitoredPipe#close}. A pipe made by other
      # code can have a thread blocked in {MonitoredPipe#write}, which holds
      # the descriptor's lock, and the reopen would wait for it with the GVL
      # held. `IO#close` interrupts such a thread first; on Ruby 3.1 `IO#reopen`
      # doesn't, and an existing {MonitoredPipe} example hangs.
      #
      # An error here must not stop the remaining pipes from being checked or
      # the leak from being repaired, and the spawn error already being raised
      # is the one the caller must see. Only the errors a close raises are
      # ignored, so an error of another class is not lost.
      #
      # @param pipe [ProcessExecuter::MonitoredPipe] the pipe to close
      #
      # @return [void]
      #
      def close_pipe(pipe)
        writer = pipe.pipe_writer
        writer.reopen(self.class.null_device) unless writer.closed?
        pipe.close(timeout: 0)
      rescue IOError, SystemCallError
        nil
      end

      # Point descriptors 1 and 2 back at their saved copies
      #
      # Works through IO objects other than STDOUT and STDERR, so those keep
      # their buffers, modes, and encodings. `IO#reopen` swaps the handle under
      # the C runtime's lock, so it waits for a write in progress on the
      # descriptor; with the pipe's reader already closed by the leak check,
      # such a write fails at once.
      #
      # @param copies [Hash{Integer => IO}] each descriptor and its copy
      #
      # @return [void]
      #
      def restore(copies)
        copies.each { |fd, copy| self.class.target(fd).reopen(copy) }
      end

      class << self
        # An IO object for descriptor 1 or 2 that a restore reopens
        #
        # Made once and kept, and first asked for before a spawn: `IO.for_fd`
        # queries the descriptor's handle, which must not happen while the
        # descriptor is leaked. It doesn't own the descriptor, so garbage
        # collection never closes a standard stream. Its mode doesn't matter:
        # `IO#reopen` takes the mode of the copy.
        #
        # @example
        #   ProcessExecuter::Commands::StandardStreamGuard.target(2).fileno #=> 2
        #
        # @param descriptor [Integer] 1 or 2
        #
        # @return [IO]
        #
        # @api private
        #
        def target(descriptor)
          (@targets ||= {})[descriptor] ||= IO.for_fd(descriptor, 'w', autoclose: false)
        end

        # An IO object open on the null device, shared by every guard
        #
        # @example
        #   ProcessExecuter::Commands::StandardStreamGuard.null_device.closed? #=> false
        #
        # @return [File]
        #
        # @api private
        #
        def null_device
          @null_device = File.open(File::NULL, 'wb') if @null_device.nil? || @null_device.closed?
          @null_device
        end
      end

      # :nocov:
    end
  end
end
