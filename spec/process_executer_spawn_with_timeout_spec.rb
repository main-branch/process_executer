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
    end

    context 'killing a timed out subprocess' do
      # A command object with a fake pid whose Process.kill calls are stubbed,
      # so the group kill and fallback paths can be tested deterministically
      # on every platform
      def command_with_stubbed_kill(**options_hash)
        options = ProcessExecuter::Options::SpawnWithTimeoutOptions.new(**options_hash)
        command = ProcessExecuter::Commands::SpawnWithTimeout.new(['exit 0'], options)
        allow(command).to receive(:pid).and_return(12_345)
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
        begin
          if command&.pid
            Process.kill('KILL', command.pid)
            Process.wait2(command.pid)
          end
        rescue Errno::ESRCH, Errno::ECHILD
          # :nocov: only reached if the subprocess exited on its own
          nil
          # :nocov:
        end
      end

      it 'should let the original exception propagate when the cleanup itself fails' do
        command = spawn_command

        # Fail every KILL so the cleanup raises internally; the ensure below
        # still needs a real TERM to pass through
        allow(Process).to receive(:kill).and_call_original
        allow(Process).to receive(:kill).with('KILL', anything).and_raise(Errno::ESRCH)

        expect { command.call }.to raise_error(Interrupt)
      ensure
        # The stubbed KILLs left the subprocess running; stop and reap it
        begin
          if command&.pid
            Process.kill('TERM', command.pid)
            Process.wait2(command.pid)
          end
        rescue Errno::ESRCH, Errno::ECHILD
          # :nocov: only reached if the subprocess exited on its own
          nil
          # :nocov:
        end
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
