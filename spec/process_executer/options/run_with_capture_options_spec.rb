# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::Options::RunWithCaptureOptions do
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
          raise_errors: true,
          merge_output: false,
          encoding: Encoding::UTF_8,
          stdout_encoding: nil,
          stderr_encoding: nil
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

    context('the option { merge_output: <value> }') { it_behaves_like 'a Boolean option', :merge_output }

    context('the option { encoding: <value> }') do
      it_behaves_like 'an encoding option', :encoding, default: Encoding::UTF_8
    end
    context('the option { stdout_encoding: <value> }') do
      it_behaves_like 'an encoding option', :stdout_encoding, default: nil
    end
    context('the option { stderr_encoding: <value> }') do
      it_behaves_like 'an encoding option', :stderr_encoding, default: nil
    end

    describe 'the merge_output: <value> option' do
      context 'when merge_output is true' do
        context 'when a stderr redirection is given' do
          let(:options_hash) { { merge_output: true, err: StringIO.new } }
          it 'should raise a ProcessExecuter::ArgumentError' do
            expect { subject }.to(
              raise_error(
                ProcessExecuter::ArgumentError,
                'Cannot give merge_output: true AND a stderr redirection'
              )
            )
          end
        end

        context 'when stdout and stderr encodings are different' do
          let(:options_hash) { { merge_output: true, stdout_encoding: Encoding::UTF_8, stderr_encoding: :binary } }
          it 'should raise a ProcessExecuter::ArgumentError' do
            expect { subject }.to(
              raise_error(
                ProcessExecuter::ArgumentError,
                'Cannot give merge_output: true AND give different encodings for stdout and stderr'
              )
            )
          end
        end
      end
    end
  end

  describe '#spawn_options' do
    non_spawn_options = {
      timeout_after: 10,
      logger: Logger.new(StringIO.new),
      raise_errors: false,
      merge_output: false,
      encoding: 'UTF-8',
      stdout_encoding: 'UTF-8',
      stderr_encoding: 'UTF-8'
    }
    it_behaves_like 'it returns only Process.spawn options', **non_spawn_options
  end

  describe '#effective_stdout_encoding' do
    subject { options.effective_stdout_encoding }

    context 'when neither stdout_encoding or encoding is given' do
      let(:options_hash) { {} }
      it 'should return the default encoding UTF-8' do
        expect(subject).to eq(Encoding::UTF_8)
      end
    end

    context 'when only stdout_encoding is given' do
      let(:options_hash) { { stdout_encoding: Encoding::BINARY } }
      it 'should return the encoding given for stdout_encoding' do
        expect(subject).to eq(Encoding::BINARY)
      end
    end

    context 'when only encoding is given' do
      let(:options_hash) { { encoding: Encoding::UTF_16 } }
      it 'should return the encoding given for encoding' do
        expect(subject).to eq(Encoding::UTF_16)
      end
    end

    context 'when both encoding and stdout_encoding are given and are different' do
      let(:options_hash) { { encoding: Encoding::UTF_16, stdout_encoding: Encoding::BINARY } }
      it 'should return what the user gave for stdout_encoding' do
        expect(subject).to eq(Encoding::BINARY)
      end
    end
  end

  describe '#effective_stderr_encoding' do
    subject { options.effective_stderr_encoding }

    context 'when neither stderr_encoding or encoding is given' do
      let(:options_hash) { {} }
      it 'should return the default encoding UTF-8' do
        expect(subject).to eq(Encoding::UTF_8)
      end
    end

    context 'when only stderr_encoding is given' do
      let(:options_hash) { { stderr_encoding: Encoding::BINARY } }
      it 'should return the encoding given for stderr_encoding' do
        expect(subject).to eq(Encoding::BINARY)
      end
    end

    context 'when only encoding is given' do
      let(:options_hash) { { encoding: Encoding::UTF_16 } }
      it 'should return the encoding given for encoding' do
        expect(subject).to eq(Encoding::UTF_16)
      end
    end

    context 'when both encoding and stderr_encoding are given and are different' do
      let(:options_hash) { { encoding: Encoding::UTF_16, stderr_encoding: Encoding::BINARY } }
      it 'should return what the user gave for stderr_encoding' do
        expect(subject).to eq(Encoding::BINARY)
      end
    end
  end
end
