# frozen_string_literal: true

RSpec.describe ProcessExecuter do
  describe '.spawn' do
    subject { ProcessExecuter.spawn(*command, **options) }

    context 'for a command that does not time out' do
      let(:command) { ['exit 1'] }
      let(:options) { {} }
      it { is_expected.to be_a(Process::Status) }
      it { is_expected.to have_attributes(exitstatus: 1) }
    end

    context 'for a command that times out' do
      let(:command) { %w[sleep 1] }
      let(:options) { { timeout: 0.01 } }

      it { is_expected.to be_a(Process::Status) }
      it 'should have killed the process' do
        expect(subject.exited?).to eq(false)
        expect(subject.signaled?).to eq(true)
        expect(subject.termsig).to eq(9)
      end
    end
  end
end
