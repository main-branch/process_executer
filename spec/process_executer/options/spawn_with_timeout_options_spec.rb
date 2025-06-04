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

    context 'when an unknown option is given' do
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { described_class.new(unknown: true) }.to(
          raise_error(ProcessExecuter::ArgumentError, 'Unknown option: unknown')
        )
      end
    end

    context('the option { timeout_after: <value> }') { it_behaves_like 'a timeout option', :timeout_after }
  end

  describe '#spawn_options' do
    non_spawn_options = {
      timeout_after: 10
    }
    it_behaves_like 'it returns only Process.spawn options', **non_spawn_options
  end
end
