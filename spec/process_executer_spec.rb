# frozen_string_literal: true

RSpec.describe ProcessExecuter do
  describe '.spawn' do
    subject { ProcessExecuter.spawn(*command, **options) }

    context 'for a command that does not time out' do
      let(:command) { %w[false] }
      let(:options) { {} }
      it { is_expected.to be_a(Process::Status) }
      it { is_expected.to have_attributes(exitstatus: 1) }
    end

    context 'for a command that times out' do
      let(:command) { %w[sleep 1] }
      let(:options) { { timeout: 0.01 } }

      it { is_expected.to be_a(Process::Status) }

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
          expect(subject.exited?).to eq(true)
          expect(subject.exitstatus).to eq(0)
        else
          # On other platforms, the status of a process killed with SIGKILL will indicate
          # that the process terminated because of the uncaught signal
          expect(subject.signaled?).to eq(true)
          expect(subject.termsig).to eq(9)
        end
        # rubocop:enable Style/RescueModifier
        # :nocov:
      end
    end
  end
end
