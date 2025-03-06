# frozen_string_literal: true

require 'English'
require 'logger'
require 'tmpdir'

RSpec.describe ProcessExecuter do
  describe '.spawn_and_wait' do
    subject { ProcessExecuter.spawn_and_wait(*command, **options) }

    context 'when :out and :err are given' do
      context 'when :out and :err are both a StringIO wrapped in a MonitoredPipe' do
        let(:command) { ruby_command <<~COMMAND }
          puts 'stdout output'
          STDERR.puts 'stderr output'
        COMMAND

        let(:options) { { out: @out_pipe, err: @err_pipe } }

        it 'should capture stdout and stderr' do
          @out_buffer = StringIO.new
          @out_pipe = ProcessExecuter::MonitoredPipe.new(@out_buffer)
          @err_buffer = StringIO.new
          @err_pipe = ProcessExecuter::MonitoredPipe.new(@err_buffer)

          begin
            result = subject
          ensure
            # Alway close the pipes to ensure resourecs are released and
            # final output is captured
            @out_pipe.close
            @err_pipe.close
            # Always raise an exception if the pipe raised an exception
            raise @out_pipe.exception if @out_pipe.exception
            raise @err_pipe.exception if @err_pipe.exception
          end

          aggregate_failures do
            expect(result.stdout.gsub("\r\n", "\n")).to eq("stdout output\n")
            expect(result.stderr.gsub("\r\n", "\n")).to eq("stderr output\n")
          end
        end
      end
    end

    context 'when :timeout_after is specified' do
      context 'when :timeout_after is a String' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout_after: 'a string' } }
        it 'should raise an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /timeout_after must be/)
        end
      end

      context 'when :timeout_after is a Complex' do
        let(:command) { %w[echo hello] }
        let(:options) { { timeout_after: Complex(3, 4) } }
        it 'should raise an ArgumentError' do
          expect { subject }.to raise_error(ArgumentError, /timeout_after must be/)
        end
      end

      context 'when :timeout_after is nil' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options) { { out: output_pipe, timeout_after: nil } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when :timeout_after is an Integer' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options) { { out: output_pipe, timeout_after: Integer(1) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when :timeout_after is a Float' do
        let(:command) { %w[echo hello] }
        let(:output_writer) { StringIO.new }
        let(:output_pipe) { ProcessExecuter::MonitoredPipe.new(output_writer) }
        let(:options) { { out: output_pipe, timeout_after: Float(1.0) } }
        it 'should NOT raise an error' do
          expect { subject }.not_to raise_error
        end
      end
    end

    context 'for a command that does not time out' do
      let(:command) { %w[false] }
      let(:options) { {} }
      it { is_expected.to be_a(ProcessExecuter::Result) }
      it { is_expected.to have_attributes(timed_out?: false, exitstatus: 1) }
    end

    def windows?
      !!(RUBY_PLATFORM =~ /mswin|win32|mingw|bccwin|cygwin/)
    rescue StandardError
      # :nocov: this code is not guaranteed to be executed
      false
      # :nocov:
    end

    context 'for a command that times out' do
      let(:command) { %w[sleep 1] }
      let(:options) { { timeout_after: 0.01 } }

      it { is_expected.to be_a(ProcessExecuter::Result) }

      it 'should have killed the process' do
        start_time = Time.now
        subject
        end_time = Time.now

        # The process should have been killed very soon after 0.01 seconds (before 1 second)
        expect(end_time - start_time).to be < 0.1

        # :nocov: execution of this code is platform dependent
        if windows?
          # On windows, the status of a process killed with SIGKILL will indicate
          # that the process exited normally with exitstatus 0.
          expect(subject).to have_attributes(exited?: true, exitstatus: 0, timed_out?: true)
        else
          # On other platforms, the status of a process killed with SIGKILL will indicate
          # that the process terminated because of the uncaught signal
          expect(subject).to have_attributes(signaled?: true, termsig: 9, timed_out?: true)
        end
        # :nocov:
      end
    end

    context 'when given a logger' do
      let(:logger) { Logger.new(log_buffer, level: log_level) }
      let(:log_buffer) { StringIO.new }
      let(:options) { { logger: logger } }
      let(:options) { { logger:, timeout_after: } }
      let(:timeout_after) { nil }

      context 'a command that returns exitstatus 0' do
        let(:command) { ruby_command <<~COMMAND }
          puts 'stdout output'
          STDERR.puts 'stderr output'
          sleep 0.05
        COMMAND

        context 'when log level is WARN' do
          let(:log_level) { Logger::WARN }
          it 'is expected not to log anything' do
            subject
            expect(log_buffer.string).to be_empty
          end
        end

        context 'when log level is INFO' do
          let(:log_level) { Logger::INFO }
          it 'is expected to log the command and its status' do
            subject
            expect(log_buffer.string).to match(/INFO -- : \[.*?\] exited with status pid \d+ exit 0$/)
            expect(log_buffer.string).not_to match(/DEBUG -- : /)
          end
        end

        context 'when log level is DEBUG' do
          let(:log_level) { Logger::DEBUG }
          context 'when :out and :err are both a StringIO wrapped in a MonitoredPipe' do
            let(:options) { { out: @out_pipe, err: @err_pipe, timeout_after:, logger: } }

            it 'should log stdout and stderr' do
              @out_buffer = StringIO.new
              @out_pipe = ProcessExecuter::MonitoredPipe.new(@out_buffer)
              @err_buffer = StringIO.new
              @err_pipe = ProcessExecuter::MonitoredPipe.new(@err_buffer)

              begin
                subject
              ensure
                # Alway close the pipes to ensure resourecs are released and
                # final output is captured
                @out_pipe.close
                @err_pipe.close
                # Always raise an exception if the pipe raised an exception
                raise @out_pipe.exception if @out_pipe.exception
                raise @err_pipe.exception if @err_pipe.exception
              end

              expect(log_buffer.string.gsub("\r\n", "\n").gsub('\r\n', '\n')).to(
                match(/DEBUG -- : stdout:\n"stdout output\\n"\nstderr:\n"stderr output\\n"$/)
              )
            end
          end
        end
      end

      context 'a command that returns exitstatus 1' do
        let(:command) { 'echo "stdout output" && echo "stderr output" 1>&2 && exit 1' }

        context 'when log level is WARN' do
          let(:log_level) { Logger::WARN }
          it 'is expected not to log anything' do
            subject
            expect(log_buffer.string).to be_empty
          end
        end

        context 'when log level is INFO' do
          let(:log_level) { Logger::INFO }
          it 'is expected to log the command and its status' do
            subject
            expect(log_buffer.string).to match(/INFO -- : \[.*?\] exited with status pid \d+ exit 1$/)
            expect(log_buffer.string).not_to match(/DEBUG -- : /)
          end
        end
      end

      context 'a command that times out' do
        let(:command) { 'sleep 1' }
        let(:timeout_after) { 0.01 }

        context 'when log level is WARN' do
          let(:log_level) { Logger::WARN }
          it 'is expected not to log anything' do
            subject
            expect(log_buffer.string).to be_empty
          end
        end

        context 'when log level is INFO' do
          let(:log_level) { Logger::INFO }
          it 'is expected to log the command and its status' do
            subject

            # :nocov: execution of this code is platform dependent
            expected_message =
              if RUBY_ENGINE == 'jruby'
                /INFO -- : \[.*?\] exited with status pid \d+ KILL \(signal 9\) timed out after 0.01s$/
              elsif RUBY_ENGINE == 'truffleruby'
                /INFO -- : \[.*?\] exited with status pid \d+ exit nil timed out after 0.01s$/
              elsif Gem.win_platform?
                /INFO -- : \[.*?\] exited with status pid \d+ exit 0 timed out after 0.01s$/
              else
                /INFO -- : \[.*?\] exited with status pid \d+ SIGKILL \(signal 9\) timed out after 0.01s$/
              end
            # :nocov:

            expect(log_buffer.string).to match(expected_message)

            expect(log_buffer.string).not_to match(/DEBUG -- : /)
          end
        end
      end
    end
  end
end
