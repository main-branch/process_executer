# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::Options::RunOptions do
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
          timeout_after: nil,
          logger: be_a(Logger).and(satisfy { |logger| logger.instance_variable_get(:@logdev).nil? }),
          raise_errors: true
        )
        expect(subject.logger.instance_variable_get(:@logdev)).to be_nil
      end
    end

    context 'when giving 10 for timeout_after' do
      let(:options_hash) { { timeout_after: 10 } }

      it 'should set timeout_after to 10' do
        expect(subject.timeout_after).to eq(10)
      end
    end

    context 'when giving 0 for timeout_after' do
      let(:options_hash) { { timeout_after: 0 } }

      it 'should set timeout_after to 0' do
        expect(subject.timeout_after).to eq(0)
      end
    end

    context 'when giving -1 for timeout_after' do
      let(:options_hash) { { timeout_after: -1 } }

      it 'should raise an error' do
        expect { subject }.to(
          raise_error(
            ProcessExecuter::ArgumentError,
            'timeout_after must be nil or a non-negative real number but was -1'
          )
        )
      end
    end

    context 'when given an invalid logger value' do
      let(:options_hash) { { logger: 'invalid' } }

      it 'should raise an error' do
        expect { subject }.to(
          raise_error(
            ProcessExecuter::ArgumentError,
            'logger must respond to #info and #debug but was "invalid"'
          )
        )
      end
    end

    context 'when giving false for raise_errors' do
      let(:options_hash) { { raise_errors: false } }

      it 'should set raise_errors to false' do
        expect(subject.raise_errors).to eq(false)
      end
    end

    context 'when given an invalid raise_errors value' do
      let(:options_hash) { { raise_errors: nil } }

      it 'should raise an error' do
        expect { subject }.to(
          raise_error(
            ProcessExecuter::ArgumentError,
            'raise_errors must be true or false but was nil'
          )
        )
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

    context 'when timeout_after and raise_errors are set' do
      let(:options_hash) { { timeout_after: 10, raise_errors: false } }

      it 'should not include the timeout_after or raise_errors options' do
        aggregate_failures do
          expect(subject).not_to have_key(:timeout_after)
          expect(subject).not_to have_key(:raise_errors)
        end
      end
    end
  end
end
