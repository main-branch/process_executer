# frozen_string_literal: true

RSpec.describe ProcessExecuter do
  describe '.spawn' do
    subject { ProcessExecuter.spawn(*command, **options) }

    context 'when :timeout is specified' do
      context 'when :timeout is a String' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout: 'a string' } }
        it 'should raise an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /timeout/)
        end
      end

      context 'when :timeout is a Complex' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout: Complex(3, 4) } }
        it 'should raise an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /timeout/)
        end
      end

      context 'when :timeout is nil' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout: nil } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when :timeout an Integer' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout: Integer(1) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when :timeout a Float' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout: Float(1.0) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end
    end

    context 'for a command that does not time out' do
      let(:command) { %w[false] }
      let(:options) { {} }
      it { is_expected.to be_a(ProcessExecuter::Status) }
      it { is_expected.to have_attributes(timeout?: false, exitstatus: 1) }
    end

    context 'for a command that times out' do
      let(:command) { %w[sleep 1] }
      let(:options) { { timeout: 0.01 } }

      it { is_expected.to be_a(ProcessExecuter::Status) }

      it 'should have killed the process' do
        start_time = Time.now
        subject
        end_time = Time.now

        # The process should have been killed very soon after 0.01 seconds (before 1 second)
        expect(end_time - start_time).to be < 0.1

        # :nocov:
        # rubocop:disable Style/RescueModifier
        if (WINDOWS = (RUBY_PLATFORM =~ /mswin|win32|mingw|bccwin|cygwin/) rescue false)
          # On windows, the status of a process killed with SIGKILL will indicate
          # that the process exited normally with exitstatus 0.
          expect(subject).to have_attributes(exited?: true, exitstatus: 0, timeout?: true)
        else
          # On other platforms, the status of a process killed with SIGKILL will indicate
          # that the process terminated because of the uncaught signal
          expect(subject).to have_attributes(signaled?: true, termsig: 9, timeout?: true)
        end
        # rubocop:enable Style/RescueModifier
        # :nocov:
      end
    end
  end
end
