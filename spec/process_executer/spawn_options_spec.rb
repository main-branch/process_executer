# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::SpawnOptions do
  let(:options) { described_class.new(**options_hash) }
  let(:options_hash) { {} }

  describe '#initialize' do
    subject { options }

    context 'when no options are given' do
      it 'should set all options to their default values' do
        expect(subject).to have_attributes(
          in: :not_set,
          out: :not_set,
          err: :not_set,
          unsetenv_others: :not_set,
          pgroup: :not_set,
          new_pgroup: :not_set,
          rlimit_resourcename: :not_set,
          umask: :not_set,
          close_others: :not_set,
          chdir: :not_set
        )
      end
    end
  end

  describe '#spawn_options' do
    subject { options.spawn_options }

    context 'when all options are set to :not_set (the default)' do
      it { is_expected.to eq({}) }
    end

    context 'when the :in option is set' do
      let(:options_hash) { { in: $stdin } }

      it { is_expected.to eq({ in: $stdin }) }
    end

    context 'when the :out option is set' do
      let(:options_hash) { { out: $stdout } }

      it { is_expected.to eq({ out: $stdout }) }
    end

    context 'when the :err option is set' do
      let(:options_hash) { { err: $stderr } }

      it { is_expected.to eq({ err: $stderr }) }
    end

    context 'when the :out and :err options are set' do
      let(:options_hash) { { out: $stdout, err: $stderr } }

      it { is_expected.to eq({ out: $stdout, err: $stderr }) }
    end
  end
end
