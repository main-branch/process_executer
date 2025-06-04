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
      end
    end

    context 'when an unknown option is given' do
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { described_class.new(unknown: true) }.to(
          raise_error(ProcessExecuter::ArgumentError, 'Unknown option: unknown')
        )
      end
    end

    context('the option { logger: <value> }') { it_behaves_like 'a logger option', :logger }
    context('the option { raise_errors: <value> }') { it_behaves_like 'a Boolean option', :raise_errors }
  end

  describe '#spawn_options' do
    non_spawn_options = {
      timeout_after: 10,
      logger: Logger.new(StringIO.new),
      raise_errors: false
    }
    it_behaves_like 'it returns only Process.spawn options', **non_spawn_options
  end
end
