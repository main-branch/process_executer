# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::Options do
  it 'should define defaults for all options' do
    expect(described_class::DEFAULTS.keys).to match_array(described_class::ALL_OPTIONS)
  end

  let(:options) { ProcessExecuter::Options.new(**options_hash) }

  let(:all_options_hash) do
    # :nocov:
    # JRuby does not count the following as covered even though it is
    {
      in: double('in'),
      out: double('out'),
      err: double('err'),
      unsetenv_others: double('unsetenv_others'),
      pgroup: double('pgroup'),
      new_pgroup: double('new_pgroup'),
      rlimit_resourcename: double('rlimit_resourcename'),
      umask: double('umask'),
      close_others: double('close_others'),
      chdir: double('chdir'),
      timeout: 0
    }
    # :nocov:
  end

  describe '#initialize' do
    subject { options }

    context 'with no options' do
      let(:options_hash) { {} }
      it { is_expected.to have_attributes(ProcessExecuter::Options::DEFAULTS) }
    end

    context 'with an option that is an Integer' do
      let(:options_hash) { { 1 => $stdout, 2 => $stderr } }

      it 'should not raise an Exception' do
        expect { subject }.not_to raise_error
      end
    end

    context 'with all valid options' do
      let(:options_hash) { all_options_hash }

      it 'should test all options' do
        # This is to make sure that the options hash includes all options
        expect(options_hash.keys).to match_array(ProcessExecuter::Options::ALL_OPTIONS)
      end

      it 'should have the expected values of all options' do
        expect(subject).to have_attributes(options_hash)
      end
    end

    context 'with an unknown option' do
      let(:options_hash) { { unknown_option: true } }
      it 'should raise an ArgumentError' do
        expect { options }.to raise_error(ArgumentError, 'Unknown options: unknown_option')
      end
    end
  end

  describe '#spawn_options' do
    subject { options.spawn_options }

    context 'when no options are given' do
      let(:options_hash) { {} }
      it { is_expected.to eq({}) }
    end

    context 'when all options are given' do
      let(:options_hash) { all_options_hash }
      let(:expected_spawn_options) do
        all_options_hash.slice(*ProcessExecuter::Options::SPAWN_OPTIONS)
      end
      it { is_expected.to eq(expected_spawn_options) }
    end

    context 'when an integer options is given' do
      let(:options_hash) { { 1 => $stdout, 2 => $stderr } }

      it 'should be included in the spawn_options' do
        expect(subject).to include(1 => $stdout, 2 => $stderr)
      end
    end

    context 'when an IO option is given' do
      let(:options_hash) { { $stdout => $stdout } }

      it 'should be included in the spawn_options' do
        expect(subject).to include($stdout => $stdout)
      end
    end
  end
end
