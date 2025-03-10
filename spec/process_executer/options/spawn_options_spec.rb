# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::Options::SpawnOptions do
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

    context 'when an unknown option is given' do
      it 'should raise an ArgumentError' do
        expect { described_class.new(unknown: true) }.to raise_error(ArgumentError, 'Unknown option: unknown')
      end
    end
  end

  describe 'redirection options' do
    context 'with an Integer source' do
      let(:options_hash) { { 1 => File::NULL } }

      it 'should allow the option' do
        expect { options }.not_to raise_error
      end

      it 'should include the option in #spawn_options' do
        expect(options.spawn_options).to include(**options_hash)
      end
    end

    context 'with an IO source' do
      let(:options_hash) { { $stdout => File::NULL } }

      it 'should allow the option' do
        expect { options }.not_to raise_error
      end

      it 'should include the option in #spawn_options' do
        expect(options.spawn_options).to include(**options_hash)
      end
    end

    context 'with an array of Integers and IOs' do
      let(:options_hash) { { [1, $stderr] => File::NULL } }

      it 'should allow the option' do
        expect { options }.not_to raise_error
      end

      it 'should include the option in #spawn_options' do
        expect(options.spawn_options).to include(**options_hash)
      end
    end

    context 'with a Symbol source' do
      let(:options_hash) { { out: File::NULL } }

      it 'allow the option' do
        expect { options }.not_to raise_error
      end

      it 'should include the option in #spawn_options' do
        expect(options.spawn_options).to include(**options_hash)
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
