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

    context 'when the same options object is used for a second run' do
      it 'is expected to run both times and capture the output of each run' do
        options = ProcessExecuter::Options::RunWithCaptureOptions.new
        result1 = described_class.run_with_capture(*command, options)
        result2 = described_class.run_with_capture(*command, options)
        expect(result1.stdout).to eq("HELLO#{eol}")
        expect(result2.stdout).to eq("HELLO#{eol}")
      end

      it "is expected to leave the caller's destination in the options object after the run" do
        my_stdout_buffer = StringIO.new
        options = ProcessExecuter::Options::RunWithCaptureOptions.new(out: my_stdout_buffer)
        described_class.run_with_capture(*command, options)
        expect(options.stdout_redirection_destination).to be(my_stdout_buffer)
      end
    end

    context 'when the caller passes their own MonitoredPipe as a destination' do
      let(:my_stdout_buffer) { StringIO.new }
      let(:user_pipe) { ProcessExecuter::MonitoredPipe.new(my_stdout_buffer) }

      # The user's pipe is the caller's to close. Close it here so a leaked
      # pipe does not fail every example that follows via the global
      # assert_no_open_instances hook in spec_helper.rb. The guard makes the
      # hook safe even when a regression closes the pipe during the run.
      after do
        user_pipe.close if user_pipe.state == :open
      end

      it "is expected not to close the caller's pipe" do
        described_class.run_with_capture(*command, out: user_pipe)
        expect(user_pipe.state).to eq(:open)
      end

      it 'is expected to allow the pipe to be reused for a second run' do
        described_class.run_with_capture(*command, out: user_pipe)
        result = described_class.run_with_capture(*command, out: user_pipe)
        expect(result.stdout).to eq("HELLO#{eol}")
        user_pipe.close
        expect(my_stdout_buffer.string).to eq("HELLO#{eol}HELLO#{eol}")
      end
    end

    describe 'the options returned by result#options' do
      it 'is expected to hold the destination the user configured, not an internal pipe' do
        my_stdout_buffer = StringIO.new
        result = described_class.run_with_capture(*command, out: my_stdout_buffer)
        expect(result.options.stdout_redirection_destination).to be(my_stdout_buffer)
      end
    end

    context 'when given a command that runs successfully and sends output to stdout and stderr' do
      describe 'encoding' do
        let(:tmpdir) { Dir.mktmpdir }
        let(:valid_utf8_file) { File.join(tmpdir, 'valid_utf8.txt') }
        let(:invalid_utf8_file) { File.join(tmpdir, 'invalid_utf8.txt') }
        let(:valid_utf8_string) { '😊'.encode('UTF-8') }
        let(:invalid_utf8_string) { "\xFF\xFE".dup.force_encoding('UTF-8') }
        let(:command) { "cat #{file_to_cat}" }
        let(:result) { described_class.run_with_capture(command, **options) }

        before do
          File.write(valid_utf8_file, valid_utf8_string)
          File.write(invalid_utf8_file, invalid_utf8_string)
        end

        after do
          FileUtils.rm_rf(tmpdir)
        end

        context 'when given an invalid encoding' do
          context 'when the option { encoding: INVALID } is given' do
            let(:options) { { encoding: 'INVALID_ENCODING' } }
            let(:file_to_cat) { valid_utf8_file }
            it 'should raise a ProcessExecuter::ArgumentError' do
              expect { result }.to raise_error(ProcessExecuter::ArgumentError, /unknown encoding/)
            end
          end

          context 'when the option { stdout_encoding: INVALID } is given' do
            let(:options) { { stdout_encoding: 'INVALID_ENCODING' } }
            let(:file_to_cat) { valid_utf8_file }
            it 'should raise a ProcessExecuter::ArgumentError' do
              expect { result }.to raise_error(ProcessExecuter::ArgumentError, /unknown encoding/)
            end
          end

          context 'when the option { stderr_encoding: INVALID } is given' do
            let(:options) { { stderr_encoding: 'INVALID_ENCODING' } }
            let(:file_to_cat) { valid_utf8_file }
            it 'should raise a ProcessExecuter::ArgumentError' do
              expect { result }.to raise_error(ProcessExecuter::ArgumentError, /unknown encoding/)
            end
          end
        end

        context 'for stdout' do
          let(:command) { "cat #{file_to_cat}" }
          let(:output) { result.stdout }

          context 'when neither the option { encoding: <value> } nor { stdout_encoding: <value> is given' do
            let(:options) { {} }
            let(:file_to_cat) { valid_utf8_file }

            it 'should return output tagged as UTF-8 encoding' do
              expect(result).to(have_attributes(exitstatus: 0))
              expect(output.encoding).to eq(Encoding::UTF_8)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string)
            end
          end

          context 'when the option { encoding: "ASCII-8BIT"  } is given' do
            let(:options) { { encoding: 'ASCII-8BIT' } }
            let(:file_to_cat) { valid_utf8_file }

            it 'should return the output in ASCII-8BIT encoding' do
              expect(result).to(have_attributes(exitstatus: 0))
              expect(output.encoding).to eq(Encoding::ASCII_8BIT)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string.dup.force_encoding(Encoding::ASCII_8BIT))
            end
          end

          context 'when the option { encoding: "UTF-8" } is given' do
            let(:options) { { encoding: 'UTF-8' } }

            context 'when output is valid UTF-8' do
              let(:file_to_cat) { valid_utf8_file }

              it 'should return the output tagged as UTF-8 encoding' do
                expect(output.encoding).to eq(Encoding::UTF_8)
              end

              it 'should return the content' do
                expect(output).to eq(valid_utf8_string)
              end

              it 'should return the output with valid_encoding? true' do
                expect(output.valid_encoding?).to be true
              end
            end

            context 'when output is NOT valid UTF-8' do
              let(:file_to_cat) { invalid_utf8_file }

              it 'should return the output tagged as UTF-8 encoding' do
                expect(output.encoding).to eq(Encoding::UTF_8)
              end

              it 'should return the content' do
                expect(output).to eq(invalid_utf8_string)
              end

              it 'should return the output with valid_encoding? true' do
                expect(output.valid_encoding?).to be false
              end
            end
          end

          context 'when the option { stdout_encoding: "ASCII-8BIT" } is given' do
            let(:options) { { stdout_encoding: 'ASCII-8BIT' } }
            let(:file_to_cat) { valid_utf8_file }

            it 'should return output tagged with ASCII-8BIT encoding' do
              expect(output.encoding).to eq(Encoding::ASCII_8BIT)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string.dup.force_encoding(Encoding::ASCII_8BIT))
            end
          end

          context 'when the options { encoding: "UTF-8", stdout_encoding: "ASCII-8BIT" } are given' do
            let(:options) { { stdout_encoding: 'ASCII-8BIT' } }
            let(:file_to_cat) { valid_utf8_file }

            it 'should use stdout_encoding and ignore encoding' do
              expect(output.encoding).to eq(Encoding::ASCII_8BIT)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string.dup.force_encoding(Encoding::ASCII_8BIT))
            end
          end
        end

        context 'for stderr' do
          let(:command) { "cat #{file_to_cat} 1>&2" }
          let(:output) { result.stderr }

          context 'when neither the option { encoding: <value> } nor { stderr_encoding: <value> is given' do
            let(:options) { {} }
            let(:file_to_cat) { valid_utf8_file }

            it 'should return output tagged as UTF-8 encoding' do
              expect(result).to(have_attributes(exitstatus: 0))
              expect(output.encoding).to eq(Encoding::UTF_8)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string)
            end
          end

          context 'when the option { encoding: "ASCII-8BIT"  } is given' do
            let(:options) { { encoding: 'ASCII-8BIT' } }
            let(:file_to_cat) { valid_utf8_file }

            it 'should return the output in ASCII-8BIT encoding' do
              expect(result).to(have_attributes(exitstatus: 0))
              expect(output.encoding).to eq(Encoding::ASCII_8BIT)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string.dup.force_encoding(Encoding::ASCII_8BIT))
            end
          end

          context 'when the option { encoding: "UTF-8" } is given' do
            let(:options) { { encoding: 'UTF-8' } }

            context 'when output is valid UTF-8' do
              let(:file_to_cat) { valid_utf8_file }

              it 'should return the output tagged as UTF-8 encoding' do
                expect(output.encoding).to eq(Encoding::UTF_8)
              end

              it 'should return the content' do
                expect(output).to eq(valid_utf8_string)
              end

              it 'should return the output with valid_encoding? true' do
                expect(output.valid_encoding?).to be true
              end
            end

            context 'when output is NOT valid UTF-8' do
              let(:file_to_cat) { invalid_utf8_file }

              it 'should return the output tagged as UTF-8 encoding' do
                expect(output.encoding).to eq(Encoding::UTF_8)
              end

              it 'should return the content' do
                expect(output).to eq(invalid_utf8_string)
              end

              it 'should return the output with valid_encoding? true' do
                expect(output.valid_encoding?).to be false
              end
            end
          end

          context 'when the option { stderr_encoding: "ASCII-8BIT" } is given' do
            let(:options) { { stderr_encoding: 'ASCII-8BIT' } }
            let(:file_to_cat) { valid_utf8_file }

            it 'should return output tagged with ASCII-8BIT encoding' do
              expect(output.encoding).to eq(Encoding::ASCII_8BIT)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string.dup.force_encoding(Encoding::ASCII_8BIT))
            end
          end

          context 'when the options { encoding: "UTF-8", stderr_encoding: "ASCII-8BIT" } are given' do
            let(:options) { { stderr_encoding: 'ASCII-8BIT' } }
            let(:file_to_cat) { valid_utf8_file }

            it 'should use stderr_encoding and ignore encoding' do
              expect(output.encoding).to eq(Encoding::ASCII_8BIT)
              expect(output.valid_encoding?).to be true
              expect(output).to eq(valid_utf8_string.dup.force_encoding(Encoding::ASCII_8BIT))
            end
          end
        end
      end

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
