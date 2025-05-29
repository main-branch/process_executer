# frozen_string_literal: true

RSpec.describe ProcessExecuter::Destinations::DestinationBase do
  describe '.handles?' do
    it 'raises NotImplementedError' do
      expect { described_class.handles?('destination') }.to raise_error(NotImplementedError)
    end
  end
end
