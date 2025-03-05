# frozen_string_literal: true

require 'English'
require 'logger'
require 'tmpdir'

RSpec.describe ProcessExecuter do
  describe '.spawn_and_wait' do
    subject { ProcessExecuter.spawn_and_wait(*command, **options) }

    context 'when :timeout_after is specified' do
      context 'when :timeout_after is a String' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout_after: 'a string' } }
        it 'should raise an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /timeout_after must be/)
        end
      end

      context 'when :timeout_after is a Complex' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout_after: Complex(3, 4) } }
        it 'should raise an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /timeout_after must be/)
        end
      end

      context 'when :timeout_after is nil' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options) { { out: output_pipe, timeout_after: nil } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when :timeout_after is an Integer' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options) { { out: output_pipe, timeout_after: Integer(1) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when :timeout_after is a Float' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options) { { out: output_pipe, timeout_after: Float(1.0) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end
    end

    context 'for a command that does not time out' do
      let(:command) { %w[false] }
      let(:options) { {} }
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

    context 'for a command that times out' do
      let(:command) { %w[sleep 1] }
      let(:options) { { timeout_after: 0.01 } }

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
