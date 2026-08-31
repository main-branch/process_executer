# frozen_string_literal: true

require 'English'
require 'logger'
require 'tmpdir'

RSpec.describe ProcessExecuter do
  describe '.spawn_with_timeout' do
    subject { ProcessExecuter.spawn_with_timeout(*command, **options_hash) }

    context 'when both a options object and an options_hash are given' do
      let(:options_hash) { { timeout_after: 1 } }
      let(:options_object) { ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 1) }
      let(:command) { ['exit 0', options_object] }
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { subject }.to(
          raise_error(
            ProcessExecuter::ArgumentError,
            'Provide either an options object or an options hash, not both.'
          )
        )
      end
    end

    context 'when an invalid command is given' do
      let(:command) { 'invalid_command' }
      let(:options_hash) { {} }
      it 'should raise an ProcessExecuter::SpawnError with the cause set' do
        expect { subject }.to(
          raise_error(ProcessExecuter::SpawnError) { |e| expect(e.cause).to be_a Errno::ENOENT }
        )
      end
    end

    context 'when :timeout_after is specified' do
      context 'when :timeout_after is a String' do
        let(:command) { %w[echo hello] }
        let(:options_hash) { { timeout_after: 'a string' } }
        it 'should raise an ProcessExecuter::ArgumentError' do
          expect { subject }.to raise_error(ProcessExecuter::ArgumentError, /timeout_after must be/)
        end
      end

      context 'when :timeout_after is a Complex' do
        let(:command) { %w[echo hello] }
        let(:options_hash) { { timeout_after: Complex(3, 4) } }
        it 'should raise an ProcessExecuter::ArgumentError' do
          expect { subject }.to raise_error(ProcessExecuter::ArgumentError, /timeout_after must be/)
        end
      end

      context 'when :timeout_after is nil' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options_hash) { { out: output_pipe, timeout_after: nil } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
          output_pipe.close
        end
      end

      context 'when :timeout_after is an Integer' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options_hash) { { out: output_pipe, timeout_after: Integer(1) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
          output_pipe.close
        end
      end

      context 'when :timeout_after is a Float' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options_hash) { { out: output_pipe, timeout_after: Float(1.0) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
          output_pipe.close
        end
      end
    end

    context 'for a command that does not time out' do
      let(:command) { %w[false] }
      let(:options_hash) { {} }
      it { is_expected.to be_a(ProcessExecuter::Result) }
      it { is_expected.to have_attributes(timed_out?: false, exitstatus: 1) }
    end

    def windows?
      !!(RUBY_PLATFORM =~ /mswin|win32|mingw|bccwin|cygwin/)
    rescue StandardError
      # :nocov: this code is not guaranteed to be executed
      false
      # :nocov:
    end

    context 'process group spawn options' do
      # The options that ProcessExecuter::Commands::SpawnWithTimeout would pass
      # to Process.spawn for the given options_hash
      def spawn_options_for(**options_hash)
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(**options_hash)
        ProcessExecuter::Commands::SpawnWithTimeout.new(['exit 0'], options).send(:spawn_options)
      end

      let(:pgroup_key) { windows? ? :new_pgroup : :pgroup }

      it 'should spawn the command in its own process group when timeout_after is set' do
        expect(spawn_options_for(timeout_after: 1)[pgroup_key]).to eq(true)
      end

      it 'should not set a process group when timeout_after is not set' do
        expect(spawn_options_for).not_to have_key(pgroup_key)
      end

      it 'should not set a process group when timeout_after is 0 (no timeout)' do
        expect(spawn_options_for(timeout_after: 0)).not_to have_key(pgroup_key)
      end

      it 'should not override a pgroup option given by the caller' do
        expect(spawn_options_for(timeout_after: 1, pgroup: 42)[:pgroup]).to eq(42)
        expect(spawn_options_for(timeout_after: 1, pgroup: 42)).not_to have_key(:new_pgroup)
      end

      it 'should not override a new_pgroup option given by the caller' do
        expect(spawn_options_for(timeout_after: 1, new_pgroup: false)[:new_pgroup]).to eq(false)
        expect(spawn_options_for(timeout_after: 1, new_pgroup: false)).not_to have_key(:pgroup)
      end

      it 'should not add its own option when the caller supplied pgroup: true' do
        expect(spawn_options_for(timeout_after: 1, pgroup: true)[:pgroup]).to eq(true)
        expect(spawn_options_for(timeout_after: 1, pgroup: true)).not_to have_key(:new_pgroup)
      end

      it 'should not add its own option when the caller supplied pgroup: 0' do
        expect(spawn_options_for(timeout_after: 1, pgroup: 0)[:pgroup]).to eq(0)
        expect(spawn_options_for(timeout_after: 1, pgroup: 0)).not_to have_key(:new_pgroup)
      end

      it 'should not add its own option when the caller supplied new_pgroup: true' do
        expect(spawn_options_for(timeout_after: 1, new_pgroup: true)[:new_pgroup]).to eq(true)
        expect(spawn_options_for(timeout_after: 1, new_pgroup: true)).not_to have_key(:pgroup)
      end
    end

    context 'killing a timed out subprocess' do
      # A command object that has spawned and reaped a fake pid (Process.spawn
      # and Process.wait2 are stubbed), so the kill path can be driven against
      # the spawn state a real call captures
      def command_with_stubbed_spawn(**options_hash)
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(**options_hash)
        command = ProcessExecuter::Commands::SpawnWithTimeout.new(['exit 0'], options)
        allow(Process).to receive(:spawn).and_return(12_345)
        allow(Process).to receive(:wait2).with(12_345).and_return([12_345, instance_double(Process::Status)])
        command.tap(&:call)
      end

      # The same, with Process.kill stubbed so the group kill and fallback
      # paths can be tested deterministically on every platform
      def command_with_stubbed_kill(**options_hash)
        command = command_with_stubbed_spawn(**options_hash)
        allow(Process).to receive(:kill).with('KILL', -12_345)
        allow(Process).to receive(:kill).with('KILL', 12_345)
        command
      end

      it 'should kill the process group when the subprocess is a new process group leader' do
        command = command_with_stubbed_kill(timeout_after: 1)
        command.send(:kill_subprocess)
        expect(Process).to have_received(:kill).with('KILL', -12_345)
        expect(Process).not_to have_received(:kill).with('KILL', 12_345)
      end

      it 'should fall back to killing the direct child when the group kill fails' do
        command = command_with_stubbed_kill(timeout_after: 1)
        allow(Process).to receive(:kill).with('KILL', -12_345).and_raise(Errno::ESRCH)
        command.send(:kill_subprocess)
        expect(Process).to have_received(:kill).with('KILL', 12_345)
      end

      it 'should kill only the direct child when the subprocess joined an existing process group' do
        command = command_with_stubbed_kill(timeout_after: 1, pgroup: 999)
        command.send(:kill_subprocess)
        expect(Process).to have_received(:kill).with('KILL', 12_345)
        expect(Process).not_to have_received(:kill).with('KILL', -12_345)
      end

      it 'should kill the process group when the caller supplied pgroup: true' do
        command = command_with_stubbed_kill(timeout_after: 1, pgroup: true)
        command.send(:kill_subprocess)
        expect(Process).to have_received(:kill).with('KILL', -12_345)
        expect(Process).not_to have_received(:kill).with('KILL', 12_345)
      end

      it 'should kill the process group when the caller supplied pgroup: 0' do
        command = command_with_stubbed_kill(timeout_after: 1, pgroup: 0)
        command.send(:kill_subprocess)
        expect(Process).to have_received(:kill).with('KILL', -12_345)
        expect(Process).not_to have_received(:kill).with('KILL', 12_345)
      end

      it 'should kill the process group when the caller supplied new_pgroup: true' do
        command = command_with_stubbed_kill(timeout_after: 1, new_pgroup: true)
        command.send(:kill_subprocess)
        expect(Process).to have_received(:kill).with('KILL', -12_345)
        expect(Process).not_to have_received(:kill).with('KILL', 12_345)
      end
    end

    context 'capturing the effective spawn options at spawn time' do
      # spawn_options is stubbed to return a different hash on each call --
      # standing in for a subclass override whose per-call state changes --
      # so a kill path that recomputed the merge instead of reusing the
      # captured hash would see a later hash and make the wrong decision
      it 'should make the group-kill decision from the options captured at spawn time' do
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new
        command = ProcessExecuter::Commands::SpawnWithTimeout.new(['exit 0'], options)
        allow(command).to receive(:spawn_options).and_return({ pgroup: true }, {})
        allow(Process).to receive(:spawn).and_return(12_345)
        allow(Process).to receive(:wait2).with(12_345).and_return([12_345, instance_double(Process::Status)])

        command.call

        expect(Process).to have_received(:spawn).with('exit 0', pgroup: true)
        expect(command.send(:process_group_leader?)).to eq(true)
      end
    end

    context 'cleaning up an abandoned wait when the caller supplied new_pgroup: true' do
      # A real spawn with new_pgroup is only possible on Windows, so the
      # cleanup decision is tested with a stubbed pid on every platform
      it 'should leave the subprocess alone' do
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 10, new_pgroup: true)
        command = ProcessExecuter::Commands::SpawnWithTimeout.new(['exit 0'], options)
        allow(command).to receive(:pid).and_return(12_345)
        allow(Process).to receive(:kill)
        allow(Process).to receive(:wait2)

        command.send(:kill_and_reap_abandoned_subprocess)

        expect(Process).not_to have_received(:kill)
        expect(Process).not_to have_received(:wait2)
      end
    end

    context 'cleaning up an abandoned wait when a subclass added its own process group option' do
      # A subclass #spawn_options override that contributes pgroup: true when
      # this class adds nothing (no timeout) makes the subprocess a group
      # leader, but not one isolated by this class, so the cleanup must leave
      # it alone
      it 'should leave the subprocess alone' do
        subclass = Class.new(ProcessExecuter::Commands::SpawnWithTimeout) do
          private

          def spawn_options = super.merge(pgroup: true)
        end
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new
        command = subclass.new(['exit 0'], options)
        allow(Process).to receive(:spawn).and_return(12_345)
        allow(Process).to receive(:wait2).with(12_345).and_return([12_345, instance_double(Process::Status)])
        command.call
        allow(Process).to receive(:kill)

        command.send(:kill_and_reap_abandoned_subprocess)

        expect(Process).not_to have_received(:kill)
      end
    end

    context 'cleaning up an abandoned wait when a subclass removed the added process group option' do
      # A subclass #spawn_options override that overrides the process group
      # option this class added (both platform keys, so whichever one was
      # added is removed) leaves the subprocess with its ordinary signal
      # semantics, so the cleanup must not kill a subprocess that was never
      # actually isolated
      it 'should leave the subprocess alone' do
        subclass = Class.new(ProcessExecuter::Commands::SpawnWithTimeout) do
          private

          def spawn_options = super.merge(pgroup: false, new_pgroup: false)
        end
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 10)
        command = subclass.new(['exit 0'], options)
        allow(Process).to receive(:spawn).and_return(12_345)
        allow(Process).to receive(:wait2).with(12_345).and_return([12_345, instance_double(Process::Status)])
        command.call
        allow(Process).to receive(:kill)

        command.send(:kill_and_reap_abandoned_subprocess)

        expect(Process).not_to have_received(:kill)
      end
    end

    context 'when the timeout fires after the subprocess was already reaped' do
      # Simulates the race where Timeout::Error is delivered after Process.wait2
      # has reaped the subprocess but before the timed block returns. The window
      # is microseconds wide, so the race is simulated by stubbing the timed
      # wait to raise Timeout::Error and making the kill and/or the follow-up
      # wait fail the way an already-reaped pid makes them fail.
      def spawn_command
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 1)
        ProcessExecuter::Commands::SpawnWithTimeout.new(ruby_command('exit 0'), options)
      end

      before do
        # Stand in for the timeout firing while waiting for the subprocess
        allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
      end

      it 'should not raise Errno::ESRCH when the kill finds the pid already gone' do
        # An already-reaped pid makes every kill raise Errno::ESRCH
        allow(Process).to receive(:kill).and_raise(Errno::ESRCH)

        command = spawn_command
        result = command.call
        expect(result.timed_out?).to eq(true)
      ensure
        # Reap the real subprocess if the wait never got to it
        begin
          Process.wait2(command.pid) if command&.pid
        rescue Errno::ECHILD
          nil
        end
      end

      it 'should return a timed out result with a nil status when the follow-up wait finds no child' do
        allow(Process).to receive(:kill)
        # The interrupted wait2 already reaped the subprocess, so the
        # follow-up wait2 finds no child and the status is lost
        allow(Process).to receive(:wait2).and_raise(Errno::ECHILD)

        command = spawn_command
        result = command.call
        expect(command.status).to be_nil
        expect(result.timed_out?).to eq(true)
        expect(result.success?).to be_nil
        expect(result.to_s).to include('timed out after 1s')
      ensure
        # Reap the real subprocess the stubbed wait2 left behind
        begin
          Process.waitpid(command.pid) if command&.pid
        rescue Errno::ECHILD
          # :nocov: only reached if the subprocess was reaped some other way
          nil
          # :nocov:
        end
      end
    end

    context 'when the wait for the subprocess is abandoned by an exception', if: !windows? do
      before do
        # Stand in for an async exception (such as Ctrl-C) arriving while
        # waiting for the subprocess
        allow(Timeout).to receive(:timeout).and_raise(Interrupt)
      end

      def spawn_command(**options_hash)
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 10, **options_hash)
        ProcessExecuter::Commands::SpawnWithTimeout.new(['sleep 60'], options)
      end

      # Stop and reap the given subprocess so it does not outlive its example
      def stop_and_reap(pid, signal: 'KILL')
        return unless pid

        Process.kill(signal, pid)
        Process.wait2(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        # :nocov: only reached if the subprocess exited on its own
        nil
        # :nocov:
      end

      it 'should kill and reap a subprocess that was isolated into its own process group' do
        command = spawn_command

        expect { command.call }.to raise_error(Interrupt)

        failure_message = 'expected the isolated subprocess to be killed when the wait was abandoned'
        expect(process_dead?(command.pid, within: 2)).to eq(true), failure_message
        # Reaped: waiting on it again reports that there is no such child
        expect { Process.wait2(command.pid) }.to raise_error(Errno::ECHILD)
      end

      it 'should leave the subprocess alone when the caller supplied its process group' do
        command = spawn_command(pgroup: Process.getpgrp)

        expect { command.call }.to raise_error(Interrupt)

        failure_message = 'expected the subprocess to keep its pre-existing behavior (left running) ' \
                          'because the caller supplied its process group'
        expect(process_dead?(command.pid, within: 0.25)).to eq(false), failure_message
      ensure
        # Do not leave the subprocess running past this example
        stop_and_reap(command&.pid)
      end

      it 'should leave the subprocess alone when the caller made it a group leader with pgroup: true' do
        command = spawn_command(pgroup: true)

        expect { command.call }.to raise_error(Interrupt)

        failure_message = 'expected the subprocess to be left running because its process group ' \
                          'came from the caller\'s own pgroup: true, not from this class'
        expect(process_dead?(command.pid, within: 0.25)).to eq(false), failure_message
      ensure
        # Do not leave the subprocess running past this example
        stop_and_reap(command&.pid)
      end

      it 'should leave the subprocess alone when the caller made it a group leader with pgroup: 0' do
        command = spawn_command(pgroup: 0)

        expect { command.call }.to raise_error(Interrupt)

        failure_message = 'expected the subprocess to be left running because its process group ' \
                          'came from the caller\'s own pgroup: 0, not from this class'
        expect(process_dead?(command.pid, within: 0.25)).to eq(false), failure_message
      ensure
        # Do not leave the subprocess running past this example
        stop_and_reap(command&.pid)
      end

      it 'should let the original exception propagate when the cleanup itself fails' do
        command = spawn_command

        # Fail every KILL so the cleanup raises internally; the ensure below
        # still needs a real TERM to pass through. Errno::EPERM is used because
        # Errno::ESRCH (an already-reaped pid) is handled and is no longer a
        # cleanup failure
        allow(Process).to receive(:kill).and_call_original
        allow(Process).to receive(:kill).with('KILL', anything).and_raise(Errno::EPERM)

        expect { command.call }.to raise_error(Interrupt)
      ensure
        # The stubbed KILLs left the subprocess running; TERM passes through
        stop_and_reap(command&.pid, signal: 'TERM')
      end
    end

    context 'for a command that times out leaving a descendant process when the caller sets pgroup', if: !windows? do
      it 'should honor the caller pgroup and kill only the direct child' do
        descendant_pid = nil
        out_reader, out_writer = IO.pipe

        # Put the command in the caller's process group: the command is not a
        # process group leader, so the group kill fails and the timeout falls
        # back to killing only the direct child
        result = ProcessExecuter.spawn_with_timeout(
          'sh', '-c', 'sleep 2 & echo $!; exec sleep 60',
          out: out_writer, timeout_after: 0.2, pgroup: Process.getpgrp
        )

        out_writer.close
        descendant_pid = out_reader.gets.to_i
        out_reader.close

        expect(result.timed_out?).to eq(true)
        expect(descendant_pid).to be > 0
        failure_message = 'expected the descendant process to survive the timeout ' \
                          'because the caller placed the command in an existing process group'
        expect(process_dead?(descendant_pid, within: 0.5)).to eq(false), failure_message
      ensure
        # Do not leave the descendant running past this example
        begin
          Process.kill('KILL', descendant_pid) if descendant_pid&.positive?
        rescue Errno::ESRCH
          # :nocov: only reached if the descendant exited on its own
          nil
          # :nocov:
        end
      end
    end

    context 'for a command that times out leaving a descendant process', if: !windows? do
      it 'should kill the descendant process too' do
        out_reader, out_writer = IO.pipe

        result = ProcessExecuter.spawn_with_timeout(
          'sh', '-c', 'sleep 3 & echo $!; exec sleep 60',
          out: out_writer, timeout_after: 0.2
        )

        out_writer.close
        # Read only the first line: reading to EOF would block until the
        # descendant (which inherited the write end of the pipe) exits
        descendant_pid = out_reader.gets.to_i
        out_reader.close

        expect(result.timed_out?).to eq(true)
        expect(descendant_pid).to be > 0
        failure_message = "expected the descendant process #{descendant_pid} to be killed " \
                          'when the command timed out, but it was still running'
        expect(process_dead?(descendant_pid, within: 2)).to eq(true), failure_message
      end
    end

    context 'for a command that times out' do
      let(:command) { %w[sleep 1] }
      let(:options_hash) { { timeout_after: 0.01 } }

      it { is_expected.to be_a(ProcessExecuter::Result) }

      it 'should have killed the process' do
        start_time = Time.now
        subject
        end_time = Time.now

        # The process should have been killed very soon after 0.01 seconds (before 1 second)
        expect(end_time - start_time).to be < 0.1

        # :nocov: execution of this code is platform dependent
        if windows?
          # On windows, the status of a process killed with SIGKILL will indicate
          # that the process exited normally with exitstatus 0.
          expect(subject).to have_attributes(exited?: true, exitstatus: 0, timed_out?: true)
        else
          # On other platforms, the status of a process killed with SIGKILL will indicate
          # that the process terminated because of the uncaught signal
          expect(subject).to have_attributes(signaled?: true, termsig: 9, timed_out?: true)
        end
        # :nocov:
      end
    end
  end
end
