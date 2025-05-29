# frozen_string_literal: true

require 'English'
require 'logger'
require 'tmpdir'

RSpec.describe ProcessExecuter do
  describe '.run_with_capture' do
    let!(:command) do
      command_separator = windows? ? '&' : ';'
      ["echo HELLO#{command_separator} echo ERROR>&2"]
    end

    let!(:eol) do
      windows? ? "\r\n" : "\n"
    end

    describe 'options' do
      context 'with no options' do
        it 'should run the command and return a result with the captured output' do
          expect(described_class.run_with_capture(*command)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: "HELLO#{eol}",
                stderr: "ERROR#{eol}"
              )
            )
          )
        end
      end

      context 'with an options_hash' do
        it 'should run the command and return a result with the captured output' do
          options = { merge_output: false }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: "HELLO#{eol}",
                stderr: "ERROR#{eol}"
              )
            )
          )
        end

        context 'with an invalid option' do
          it 'raises a ProcessExecuter::ArgumentError' do
            options = { invalid_option: true }
            expect { described_class.run_with_capture(*command, **options) }.to(
              raise_error(ProcessExecuter::ArgumentError)
            )
          end
        end
      end

      context 'with an options object' do
        context 'when the options object is a ProcessExecuter::Options::RunWithCaptureOptions' do
          it 'should run the command and return a result with the captured output' do
            options = ProcessExecuter::Options::RunWithCaptureOptions.new(merge_output: false)
            expect(described_class.run_with_capture(*command, options)).to(
              be_a(ProcessExecuter::ResultWithCapture).and(
                have_attributes(
                  stdout: "HELLO#{eol}",
                  stderr: "ERROR#{eol}"
                )
              )
            )
          end
        end

        context 'when the options object is some other kind of object' do
          it 'raises a ProcessExecuter::SpawnError' do
            options = Object.new
            expect { described_class.run_with_capture(*command, options) }.to(
              raise_error(ProcessExecuter::SpawnError)
            )
          end
        end
      end
    end

    context 'when the user gives an invalid merge_output value' do
      it 'raises a ProcessExecuter::ArgumentError' do
        options = { merge_output: 'invalid' }
        expect { described_class.run_with_capture(*command, **options) }.to(
          raise_error(ProcessExecuter::ArgumentError)
        )
      end
    end

    context 'when the user gives a stdout or stderr redirection' do
      context 'when the user gives a stdout redirection' do
        it 'should send output to the given stdout redirection AND capture it' do
          my_stdout_buffer = StringIO.new
          options = { out: my_stdout_buffer }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: "HELLO#{eol}",
                stderr: "ERROR#{eol}"
              )
            )
          )
          expect(my_stdout_buffer.string).to eq("HELLO#{eol}")
        end

        context 'when that stdout redirection is a :tee' do
          it 'should send output to the given stdout redirection AND capture it' do
            my_stdout_buffer1 = StringIO.new
            my_stdout_buffer2 = StringIO.new
            options = { out: [:tee, my_stdout_buffer1, my_stdout_buffer2] }
            expect(described_class.run_with_capture(*command, **options)).to(
              be_a(ProcessExecuter::ResultWithCapture).and(
                have_attributes(
                  stdout: "HELLO#{eol}",
                  stderr: "ERROR#{eol}"
                )
              )
            )
            expect(my_stdout_buffer1.string).to eq("HELLO#{eol}")
            expect(my_stdout_buffer2.string).to eq("HELLO#{eol}")
          end
        end
      end

      context 'when the user gives a stdout redirection and merge_output: true' do
        it 'should capture the merged stdout and stderr to the given redirection and capture it' do
          my_stdout_buffer = StringIO.new
          options = { out: my_stdout_buffer, merge_output: true }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: include("HELLO#{eol}").and(include("ERROR#{eol}")),
                stderr: ''
              )
            )
          )
          expect(my_stdout_buffer.string).to include("HELLO#{eol}").and(include("ERROR#{eol}"))
        end

        context 'when that stderr redirection is a :tee' do
          it 'should send output to the given stderr redirection AND capture it' do
            my_stderr_buffer1 = StringIO.new
            my_stderr_buffer2 = StringIO.new
            options = { err: [:tee, my_stderr_buffer1, my_stderr_buffer2] }
            expect(described_class.run_with_capture(*command, **options)).to(
              be_a(ProcessExecuter::ResultWithCapture).and(
                have_attributes(
                  stdout: "HELLO#{eol}",
                  stderr: "ERROR#{eol}"
                )
              )
            )
            expect(my_stderr_buffer1.string).to eq("ERROR#{eol}")
            expect(my_stderr_buffer2.string).to eq("ERROR#{eol}")
          end
        end
      end

      context 'when the user gives a stderr redirection' do
        it 'should send output to the given stdout redirection AND capture it' do
          my_stderr_buffer = StringIO.new
          options = { err: my_stderr_buffer }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: "HELLO#{eol}",
                stderr: "ERROR#{eol}"
              )
            )
          )
          expect(my_stderr_buffer.string).to eq("ERROR#{eol}")
        end
      end

      context 'when the user gives a stderr redirection and merge_output: true' do
        it 'raises a ProcessExecuter::ArgumentError' do
          my_stderr_buffer = StringIO.new
          options = { err: my_stderr_buffer, merge_output: true }
          expect { described_class.run_with_capture(*command, **options) }.to(
            raise_error(ProcessExecuter::ArgumentError)
          )
        end
      end
    end

    context 'when given a command that runs successfully and sends output to stdout and stderr' do
      context 'when a logger is given' do
        let(:log_buffer) { StringIO.new }
        let(:logger) { Logger.new(log_buffer) }
        let(:options) { { logger: logger } }
        it 'should run the command and log the output' do
          result = described_class.run_with_capture(*command, **options)

          expect(result).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: "HELLO#{eol}",
                stderr: "ERROR#{eol}"
              )
            )
          )

          expect(log_buffer.string).to match(/DEBUG -- : PID \d+: stdout: "HELLO(\\r)?\\n"$/)
          expect(log_buffer.string).to match(/DEBUG -- : PID \d+: stderr: "ERROR(\\r)?\\n"$/)
        end
      end

      it 'should run the command and return a result with the captured output' do
        result = nil
        expect { result = described_class.run_with_capture(*command) }.not_to raise_error
        expect(result).to(
          be_a(ProcessExecuter::ResultWithCapture).and(
            have_attributes(
              stdout: "HELLO#{eol}",
              stderr: "ERROR#{eol}"
            )
          )
        )
      end

      context 'when merge_output is false' do
        it 'should run the command and return a result with output for stdout and stderr captured separately' do
          result = nil
          options = { merge_output: false }
          expect { result = described_class.run_with_capture(*command, **options) }.not_to raise_error
          expect(result).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: "HELLO#{eol}",
                stderr: "ERROR#{eol}"
              )
            )
          )
        end
      end

      context 'when merge_output is true' do
        it 'should run the command and return a result with output for stdout and stderr captured in stdout' do
          result = nil
          options = { merge_output: true }
          expect { result = described_class.run_with_capture(*command, **options) }.not_to raise_error
          expect(result).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(stdout: including("HELLO#{eol}")).and(
                have_attributes(stdout: including("ERROR#{eol}"))
              )
            )
          )
        end
      end
    end
  end
end
