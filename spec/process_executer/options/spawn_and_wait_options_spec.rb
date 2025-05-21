# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::Options::SpawnWithTimeoutOptions do
  let(:options) { described_class.new(**options_hash) }
  let(:options_hash) { {} }

  describe '#initialize' do
    subject { options }

    context 'when no options are given' do
      it 'should set all options to their default values' do
        expect(subject).to have_attributes(
          unsetenv_others: :not_set,
          pgroup: :not_set,
          new_pgroup: :not_set,
          rlimit_resourcename: :not_set,
          umask: :not_set,
          close_others: :not_set,
          chdir: :not_set,
          timeout_after: nil
        )
      end
    end

    context 'when given timeout_after: nil' do
      let(:options_hash) { { timeout_after: nil } }

      it 'should set timeout_after to nil' do
        expect(subject.timeout_after).to eq(nil)
      end
    end

    context 'when given timeout_after: 10' do
      let(:options_hash) { { timeout_after: 10 } }

      it 'should set timeout_after to 10' do
        expect(subject.timeout_after).to eq(10)
      end
    end

    context 'when given timeout_after "invalid"' do
      let(:options_hash) { { timeout_after: 'invalid' } }

      it 'should raise an error' do
        expect { subject }.to(
          raise_error(
            ProcessExecuter::ArgumentError,
            'timeout_after must be nil or a non-negative real number but was "invalid"'
          )
        )
      end
    end
  end

  describe '#spawn_options' do
    subject { options.spawn_options }

    context 'when timeout_after is set' do
      let(:options_hash) { { timeout_after: 10 } }

      it 'should not include the timeout_after option' do
        expect(subject).not_to have_key(:timeout_after)
      end
    end
  end
end
