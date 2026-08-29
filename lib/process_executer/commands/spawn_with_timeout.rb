# frozen_string_literal: true

require_relative '../errors'

module ProcessExecuter
  module Commands
    # Spawns a subprocess, waits until it completes, and returns the result
    #
    # Wraps `Process.spawn` to provide the core functionality for
    # {ProcessExecuter.spawn_with_timeout}.
    #
    # It accepts all [Process.spawn execution
    # options](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-Execution+Options)
    # plus the additional option `timeout_after`.
    #
    # @api private
    #
    class SpawnWithTimeout
      # Create a new SpawnWithTimeout instance
      #
      # @example
      #   options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 5)
      #   result = ProcessExecuter::Commands::SpawnWithTimeout.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
      #
      # @param command [Array<String>] The command to run in the subprocess
      # @param options [ProcessExecuter::Options::SpawnWithTimeoutOptions] The options to use when spawning the process
      #
      def initialize(command, options)
        @command = command
        @options = options
      end

      # Run a command and return the result
      #
      # @example
      #   options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 5)
      #   result = ProcessExecuter::Commands::SpawnWithTimeout.new('echo hello', options).call
      #   result.success? # => true
      #   result.exitstatus # => 0
      #   result.timed_out? # => false
      #
      # @raise [ProcessExecuter::SpawnError] `Process.spawn` raised an error before the
      #   command was run
      #
      # @return [ProcessExecuter::Result] The result of the completed subprocess
      #
      def call
        begin
          @pid = Process.spawn(*command, **spawn_options)
        rescue StandardError => e
          raise ProcessExecuter::SpawnError, "Failed to spawn process: #{e.message}"
        end

        wait_for_process
      end

      # The command to be run in the subprocess
      # @see Process.spawn
      # @example
      #   spawn.command #=> ['echo', 'hello']
      # @return [Array<String>]
      attr_reader :command

      # The options that were used to spawn the process
      # @example
      #   spawn.options #=> ProcessExecuter::Options::SpawnWithTimeoutOptions
      # @return [ProcessExecuter::Options::SpawnWithTimeoutOptions]
      attr_reader :options

      # The process ID of the spawned subprocess
      #
      # @example
      #   spawn.pid #=> 12345
      #
      # @return [Integer]
      #
      attr_reader :pid

      # The status returned by Process.wait2
      #
      # @example
      #   spawn.status #=> #<Process::Status: pid 12345 exit 0>
      #
      # @return [Process::Status]
      #
      attr_reader :status

      # Whether the process timed out
      #
      # @example
      #   spawn.timed_out? #=> true
      #
      # @return [Boolean]
      #
      attr_reader :timed_out

      alias timed_out? timed_out

      # The elapsed time in seconds that the command ran
      #
      # @example
      #   spawn.elapsed_time #=> 1.234
      #
      # @return [Numeric]
      #
      attr_reader :elapsed_time

      # The result of the completed subprocess
      #
      # @example
      #   spawn.result #=> ProcessExecuter::Result
      #
      # @return [ProcessExecuter::Result]
      #
      attr_reader :result

      private

      # The options to pass to Process.spawn
      #
      # Subclasses may override this method to combine internal redirections
      # with the user's options without modifying the options object the
      # caller gave.
      #
      # @return [Hash]
      #
      def spawn_options = options.spawn_options.merge(process_group_options)

      # Spawn options that place the subprocess into its own process group
      #
      # When `timeout_after` is set to a value that can fire (`nil` and `0`
      # mean "no timeout"), the subprocess is made the leader of a new process
      # group so that a timeout can kill the whole group -- including
      # descendants that inherited the redirections -- instead of just the
      # direct child. Empty when no timeout can fire or when the caller gave a
      # `pgroup`/`new_pgroup` option themselves (their setting is honored).
      #
      # A new process group is a background group for any terminal the
      # subprocess inherits, so an interactive subprocess that reads the
      # terminal is stopped by `SIGTTIN` and then killed when the timeout
      # fires -- which is the bound `timeout_after` promises. A caller who
      # needs an interactive subprocess to stay in the foreground process
      # group can pass their own `pgroup` option.
      #
      # @return [Hash]
      #
      def process_group_options
        return {} unless options.timeout_after&.positive?
        return {} unless options.pgroup == :not_set && options.new_pgroup == :not_set

        windows? ? { new_pgroup: true } : { pgroup: true }
      end

      # Whether the current platform is Windows
      #
      # @return [Boolean]
      #
      def windows? = Gem.win_platform?

      # Wait for process to terminate
      #
      # If a `:timeout_after` is specified in options, terminate the process after the
      # specified number of seconds.
      #
      # @return [ProcessExecuter::Result] The result of the completed subprocess
      #
      def wait_for_process
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @status, @timed_out = wait_for_process_raw
        @elapsed_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        @result = create_result
      end

      # Create a result object that includes the status, command, and other details
      #
      # @return [ProcessExecuter::Result] The result of the command
      #
      def create_result
        ProcessExecuter::Result.new(status, command:, options:, timed_out:, elapsed_time:)
      end

      # Wait for a process to terminate returning the status and timed out flag
      #
      # An exception other than the timeout (an `Interrupt` from Ctrl-C, for
      # example) abandons the wait; {#kill_and_reap_abandoned_subprocess} then
      # cleans up a subprocess this class isolated into its own process group
      # before the exception propagates.
      #
      # @return [Array<Process::Status, Boolean>] an array containing the process status and a boolean
      #   indicating whether the process timed out
      def wait_for_process_raw
        wait_with_timeout
      rescue Exception # rubocop:disable Lint/RescueException
        kill_and_reap_abandoned_subprocess
        raise
      end

      # Wait for the process, killing it when `timeout_after` expires first
      #
      # @return [Array<Process::Status, Boolean>] an array containing the process status and a boolean
      #   indicating whether the process timed out
      def wait_with_timeout
        process_status = Timeout.timeout(options.timeout_after) { Process.wait2(pid).last }
        [process_status, false]
      rescue Timeout::Error
        kill_subprocess
        [Process.wait2(pid).last, true]
      end

      # Kill and reap the subprocess when its wait was abandoned by an exception
      #
      # Only applies to a subprocess this class isolated into its own process
      # group: such a subprocess no longer receives terminal-generated signals
      # (Ctrl-C sends `SIGINT` to the caller's foreground group, not to the
      # new group), so an exception that abandons the wait would otherwise
      # leave it and its descendants running unsupervised and unreaped. A
      # subprocess whose process group came from the caller's own options
      # keeps its pre-existing signal semantics and is left alone.
      #
      # Rescues `Exception` (not just `StandardError`) so that a second async
      # exception delivered during this best-effort cleanup cannot replace
      # the exception already being re-raised by the caller.
      #
      # @return [void]
      #
      def kill_and_reap_abandoned_subprocess
        return unless isolated_in_new_process_group?

        kill_subprocess
        Process.wait2(pid)
      rescue Exception # rubocop:disable Lint/RescueException
        # the subprocess may already be dead and reaped; the wait's exception
        # is what must propagate
      end

      # Forcibly terminate the timed out subprocess and (if possible) its descendants
      #
      # When the subprocess was spawned as the leader of its own process
      # group, the whole group is killed so that descendants that would
      # otherwise survive the timeout (and keep any inherited redirection
      # file descriptors open) are terminated too, falling back to killing
      # the direct child if the group kill fails. A group signal reaches only
      # the processes still in that group: a descendant that started its own
      # session or joined another process group (a daemon, for example) is
      # not killed. Otherwise the subprocess is in a process group this
      # object did not create, so only the direct child is killed, matching
      # the pre-process-group behavior.
      #
      # Killing a process group is only possible on POSIX platforms. On
      # Windows, `Process.kill` cannot signal a process group (a negative pid
      # raises an error), so the group kill always falls back to the direct
      # child and descendants may survive the timeout; the bounded
      # {MonitoredPipe#close} keeps such descendants from blocking
      # {ProcessExecuter.run} indefinitely.
      #
      # @return [void]
      #
      def kill_subprocess
        return if process_group_leader? && kill_process_group

        Process.kill('KILL', pid)
      end

      # Whether the spawn options made the subprocess a new process group leader
      #
      # True when the process group option -- added by {#process_group_options}
      # or given by the caller -- asks for a new process group with the
      # subprocess as its leader (`pgroup: true`, `pgroup: 0`, or
      # `new_pgroup: true`). False when there is no process group option or
      # when `pgroup` places the subprocess in an existing process group.
      #
      # @return [Boolean]
      #
      def process_group_leader?
        [true, 0].include?(spawn_options[:pgroup]) || spawn_options[:new_pgroup] == true
      end

      # Whether this class isolated the subprocess into its own process group
      #
      # True when the subprocess is a new process group leader and that came
      # from {#process_group_options} rather than from a `pgroup`/`new_pgroup`
      # option the caller supplied.
      #
      # @return [Boolean]
      #
      def isolated_in_new_process_group?
        process_group_leader? && options.pgroup == :not_set && options.new_pgroup == :not_set
      end

      # Send SIGKILL to the subprocess's process group
      #
      # @return [Boolean] true if the signal was sent, false if doing so raised an error
      #
      def kill_process_group
        Process.kill('KILL', -pid)
        true
      rescue StandardError
        false
      end
    end
  end
end
