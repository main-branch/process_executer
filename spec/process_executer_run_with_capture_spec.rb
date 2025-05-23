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
          options = { merge_output: true }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: include("HELLO#{eol}").and(include("ERROR#{eol}")),
                stderr: ''
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
            options = ProcessExecuter::Options::RunWithCaptureOptions.new(merge_output: true)
            expect(described_class.run_with_capture(*command, options)).to(
              be_a(ProcessExecuter::ResultWithCapture).and(
                have_attributes(
                  stdout: include("HELLO#{eol}").and(include("ERROR#{eol}")),
                  stderr: ''
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

    context 'when the user overrides stdout or stderr capture' do
      context 'when the user gives a stdout redirection' do
        it 'overrides the stdout capture' do
          my_stdout_buffer = StringIO.new
          options = { out: my_stdout_buffer }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: '',
                stderr: "ERROR#{eol}"
              )
            )
          )
          expect(my_stdout_buffer.string).to eq("HELLO#{eol}")
        end
      end

      context 'when the user gives a stdout redirection and merge_output: true' do
        it 'overrides the stdout capture' do
          my_stdout_buffer = StringIO.new
          options = { out: my_stdout_buffer, merge_output: true }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: '',
                stderr: ''
              )
            )
          )
          expect(my_stdout_buffer.string).to include("HELLO#{eol}").and(include("ERROR#{eol}"))
        end
      end

      context 'when the user gives a stderr redirection' do
        it 'overrides the stderr capture' do
          my_stderr_buffer = StringIO.new
          options = { err: my_stderr_buffer }
          expect(described_class.run_with_capture(*command, **options)).to(
            be_a(ProcessExecuter::ResultWithCapture).and(
              have_attributes(
                stdout: "HELLO#{eol}",
                stderr: ''
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
