# frozen_string_literal: true

RSpec.describe ProcessExecuter do
  describe '.spawn_options' do
    subject { ProcessExecuter.spawn_options(given_options) }

    context 'when given options is a Hash' do
      let(:given_options) { { out: $stdout } }
      it 'should return a SpawnOptions object with the same options' do
        expect(subject).to be_a(ProcessExecuter::SpawnOptions)
        expect(subject.to_h).to include(given_options)
      end
    end

    context 'when given options is a ProcessExecuter::SpawnOptions' do
      let(:given_options) { ProcessExecuter::SpawnOptions.new(out: $stdout) }
      it 'should return the given object' do
        expect(subject.object_id).to eq(given_options.object_id)
      end
    end

    context 'when given options any other kind of option' do
      let(:given_options) { Object.new }
      it 'should raise an ArgumentError' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.spawn_and_wait_options' do
    subject { ProcessExecuter.spawn_and_wait_options(given_options) }

    context 'when given options is a Hash' do
      let(:given_options) { { timeout_after: 10 } }
      it 'should return a SpawnAndWaitOptions object with the same options' do
        expect(subject).to be_a(ProcessExecuter::SpawnAndWaitOptions)
        expect(subject.to_h).to include(given_options)
      end
    end

    context 'when given options is a ProcessExecuter::SpawnAndWaitOptions' do
      let(:given_options) { ProcessExecuter::SpawnAndWaitOptions.new(timeout_after: 10) }
      it 'should return the given object' do
        expect(subject.object_id).to eq(given_options.object_id)
      end
    end

    context 'when given options any other kind of option' do
      let(:given_options) { Object.new }
      it 'should raise an ArgumentError' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.run_options' do
    subject { ProcessExecuter.run_options(given_options) }

    context 'when given options is a Hash' do
      let(:given_options) { { merge: true } }
      it 'should return a RunOptions object with the same options' do
        expect(subject).to be_a(ProcessExecuter::RunOptions)
        expect(subject.to_h).to include(given_options)
      end
    end

    context 'when given options is a ProcessExecuter::RunOptions' do
      let(:given_options) { ProcessExecuter::RunOptions.new(merge: true) }
      it 'should return the given object' do
        expect(subject.object_id).to eq(given_options.object_id)
      end
    end

    context 'when given options any other kind of option' do
      let(:given_options) { Object.new }
      it 'should raise an ArgumentError' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end
end
