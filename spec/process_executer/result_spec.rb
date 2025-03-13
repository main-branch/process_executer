# frozen_string_literal: true

RSpec.describe ProcessExecuter::Result do
  let(:result) { described_class.new(status, command:, options:, timed_out:, elapsed_time:) }

  let(:status) do
    pid, status = Process.wait2(Process.spawn(*command, **options.spawn_options))
    options.stdout_redirection_value.close
    options.stderr_redirection_value.close

    status
  end

  let(:options) do
    stdout_pipe = ProcessExecuter::MonitoredPipe.new(StringIO.new)
    stderr_pipe = ProcessExecuter::MonitoredPipe.new(StringIO.new)

    ProcessExecuter::Options::RunOptions.new(out: stdout_pipe, err: stderr_pipe)
  end

  let(:timed_out) { false }

  let(:elapsed_time) { 1.0 }

  describe 'stdout handling' do
    let(:command) { ['echo hello'] }

    describe '#stdout' do
      subject { result.stdout }
      it { is_expected.to eq("hello\n") }
    end

    describe '#unprocessed_stdout' do
      subject { result.unprocessed_stdout }
      it { is_expected.to eq("hello\n") }
    end

    describe '#process_stdout' do
      context 'without a block' do
        subject { result.process_stdout }
        it { is_expected.to be_nil }
      end

      context 'with a block' do
        context 'when called once' do
          before { result.process_stdout { |stdout| stdout.upcase } }

          it 'should replace stdout with the processed value' do
            expect(result.stdout).to eq("HELLO\n")
          end

          it '#unprocessed_stdout should return the original value' do
            expect(result.unprocessed_stdout).to eq("hello\n")
          end
        end

        context 'when called twice' do
          before do
            result.process_stdout { |stdout| stdout.upcase }
            result.process_stdout { |stdout| stdout + stdout }
          end

          it 'should replace stdout with the processed value' do
            expect(result.stdout).to eq("HELLO\nHELLO\n")
          end

          it '#unprocessed_stdout should return the original value' do
            expect(result.unprocessed_stdout).to eq("hello\n")
          end
        end
      end
    end
  end

  describe 'stderr handling' do
    let(:command) { ['echo hello 1>&2'] }

    describe '#stderr' do
      subject { result.stderr }
      it { is_expected.to eq("hello\n") }
    end

    describe '#unprocessed_stderr' do
      subject { result.unprocessed_stderr }
      it { is_expected.to eq("hello\n") }
    end

    describe '#process_stderr' do
      context 'without a block' do
        subject { result.process_stderr }
        it { is_expected.to be_nil }
      end

      context 'with a block' do
        context 'when called once' do
          before { result.process_stderr { |stderr| stderr.upcase } }

          it 'should replace stderr with the processed value' do
            expect(result.stderr).to eq("HELLO\n")
          end

          it '#unprocessed_stderr should return the original value' do
            expect(result.unprocessed_stderr).to eq("hello\n")
          end
        end

        context 'when called twice' do
          before do
            result.process_stderr { |stderr| stderr.upcase }
            result.process_stderr { |stderr| stderr + stderr }
          end

          it 'should replace stderr with the processed value' do
            expect(result.stderr).to eq("HELLO\nHELLO\n")
          end

          it '#unprocessed_stderr should return the original value' do
            expect(result.unprocessed_stderr).to eq("hello\n")
          end
        end
      end
    end
  end
end
