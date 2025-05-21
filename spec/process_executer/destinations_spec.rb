# frozen_string_literal: true

RSpec.describe ProcessExecuter::Destinations do
  describe '.compatible_with_monitored_pipe?' do
    subject { described_class.compatible_with_monitored_pipe?(destination) }
    context 'when the destination is not valid' do
      let(:destination) { Object.new }
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { subject }.to(
          raise_error(ProcessExecuter::ArgumentError, 'wrong exec redirect action')
        )
      end
    end
  end
end
