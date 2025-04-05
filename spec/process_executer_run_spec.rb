# frozen_string_literal: true

require 'English'
require 'logger'
require 'tmpdir'

RSpec.describe ProcessExecuter do
  describe '.run' do
    context 'with command given as a single string' do
      let(:command) { windows? ? 'echo %VAR%' : 'echo $VAR' }
      subject { ProcessExecuter.run({ 'VAR' => 'test' }, command, out: StringIO.new) }
      it { is_expected.to be_a(ProcessExecuter::Result) }
      it { is_expected.to have_attributes(success?: true, exitstatus: 0, signaled?: false, timed_out?: false) }
      it 'is expected to process the command with the shell and do shell expansions' do
        expect(subject.stdout.gsub("\r\n", "\n")).to eq("test\n")
      end
    end

    let(:result) { ProcessExecuter.run(*command, logger: logger, **options) }
    let(:logger) { Logger.new(nil) }

    # By default, capture stdout and stderr
    let(:options) { { out: StringIO.new, err: StringIO.new } }

    subject { result }

    # rubocop:disable Style/GlobalStdStream

    context 'with a command that does not redirect stdout' do
      let(:command) { ruby_command <<~COMMAND }
        STDOUT.puts 'stdout output'
        STDERR.puts 'stderr output'
      COMMAND

      it 'should pass stdout to the parent process' do
        # Create a pipe
        reader, writer = IO.pipe

        # Save original stdout IO object
        original_stdout = STDOUT.dup # This correctly duplicates the IO object

        # Redirect stdout at the file descriptor level
        STDOUT.reopen(writer)

        # Run the subject of the test
        ProcessExecuter.run(*ruby_command('STDOUT.puts "stdout output"'))

        # Close write end in parent so read doesn't hang
        writer.close

        # Restore original stdout
        STDOUT.reopen(original_stdout)
        original_stdout.close

        # Read the captured output
        output = reader.read
        reader.close

        expect(output).to eq("stdout output\n")
      end

      it 'should pass stderr to the parent process' do
        # Create a pipe
        reader, writer = IO.pipe

        # Save original stderr IO object
        original_stderr = STDERR.dup # This correctly duplicates the IO object
        # Redirect stderr at the file descriptor level
        STDERR.reopen(writer)

        # Run the subject of the test
        ProcessExecuter.run(*ruby_command('STDERR.puts "stderr output"'))

        # Close write end in parent so read doesn't hang
        writer.close

        # Restore original stderr
        STDERR.reopen(original_stderr)
        original_stderr.close

        # Read the captured output
        output = reader.read
        reader.close

        expect(output).to eq("stderr output\n")
      end
    end

    # rubocop:enable Style/GlobalStdStream

    context 'with a command that returns exitstatus 0' do
      let(:command) { ruby_command <<~COMMAND }
        STDOUT.puts 'stdout output'
        STDERR.puts 'stderr output'
      COMMAND

      it { is_expected.to be_a(ProcessExecuter::Result) }
      it { is_expected.to have_attributes(success?: true, exitstatus: 0, signaled?: false, timed_out?: false) }

      it 'is expected to capture the command output' do
        expect(subject.stdout.gsub("\r\n", "\n")).to eq("stdout output\n")
        expect(subject.stderr.gsub("\r\n", "\n")).to eq("stderr output\n")
      end
    end

    context 'with a command that returns exitstatus 1' do
      let(:command) { ruby_command <<~COMMAND }
        puts 'stdout output'
        STDERR.puts 'stderr output'
        exit 1
      COMMAND

      it 'is expected to raise an command error' do
        expect { result }.to raise_error(ProcessExecuter::Error)
      end

      context 'the error raised' do
        subject { result rescue $ERROR_INFO } # rubocop:disable Style/RescueModifier

        it { is_expected.to be_a(ProcessExecuter::FailedError) }

        it 'is expected to have the expected error message' do
          pid = subject.result.pid
          # SimpleCov gives a false positive on the following line under JRuby
          expect(subject.message.gsub('\\r\\n', '\\n')).to eq(
            %(#{command.inspect}, status: pid #{pid} exit 1, stderr: "stderr output\\n")
          )
        end

        context 'the result object contained in the error' do
          subject { result rescue $ERROR_INFO.result } # rubocop:disable Style/RescueModifier

          it { is_expected.to be_a(ProcessExecuter::Result) }
          it { is_expected.to have_attributes(success?: false, exitstatus: 1) }
          it 'is expected have the output from the command' do
            expect(subject.stdout.gsub("\r\n", "\n")).to eq("stdout output\n")
            expect(subject.stderr.gsub("\r\n", "\n")).to eq("stderr output\n")
          end
        end
      end
    end

    context 'with a command that times out' do
      let(:command) { 'sleep 1' }
      let(:options) { { timeout_after: 0.01, out: StringIO.new, err: StringIO.new } }

      it 'is expected to raise an error' do
        expect { subject }.to raise_error(ProcessExecuter::Error)
      end

      context 'the error raised' do
        subject { result rescue $ERROR_INFO } # rubocop:disable Style/RescueModifier

        it { is_expected.to be_a(ProcessExecuter::TimeoutError) }

        it 'is expected to have the expected error message' do
          pid = subject.result.pid
          # :nocov: execution of this code is platform dependent
          expected_message =
            if jruby?
              %(["sleep 1"], status: pid #{pid} KILL (signal 9) timed out after 0.01s, stderr: "")
            elsif truffleruby?
              %(["sleep 1"], status: pid #{pid} exit nil timed out after 0.01s, stderr: "")
            elsif windows?
              %(["sleep 1"], status: pid #{pid} exit 0 timed out after 0.01s, stderr: "")
            else
              %(["sleep 1"], status: pid #{pid} SIGKILL (signal 9) timed out after 0.01s, stderr: "")
            end
          # :nocov:

          expect(subject.message).to eq expected_message
        end

        context 'the result object contained in the error' do
          subject { result rescue $ERROR_INFO.result } # rubocop:disable Style/RescueModifier

          it { is_expected.to be_a(ProcessExecuter::Result) }
          it { is_expected.to have_attributes(success?: nil, timed_out?: true) }
        end
      end
    end

    context 'with a command that exits due to an unhandled signal', if: !windows? do
      let(:command) { ruby_command <<~COMMAND }
        puts 'Hello world'
        Process.kill('KILL', Process.pid)
      COMMAND

      it 'is expected to raise an error' do
        expect { subject }.to raise_error(ProcessExecuter::Error)
      end

      context 'the error raised' do
        subject { result rescue $ERROR_INFO } # rubocop:disable Style/RescueModifier

        it { is_expected.to be_a(ProcessExecuter::SignaledError) }

        it 'is expected to have the expected error message' do
          pid = subject.result.pid

          # :nocov: execution of this code is platform dependent
          expected_message =
            if jruby?
              %(#{command.inspect}, status: pid #{pid} KILL (signal 9), stderr: "")
            elsif truffleruby?
              %(#{command.inspect}, status: pid #{pid} exit nil, stderr: "")
            else
              %(#{command.inspect}, status: pid #{pid} SIGKILL (signal 9), stderr: "")
            end
          # :nocov:

          expect(subject.message).to eq(expected_message)
        end

        context 'the result object contained in the error' do
          subject { result rescue $ERROR_INFO.result } # rubocop:disable Style/RescueModifier

          it { is_expected.to be_a(ProcessExecuter::Result) }
          it { is_expected.to have_attributes(signaled?: true, termsig: 9) }
        end
      end
    end

    context 'with raise_errors set to false' do
      context 'a command that returns exitstatus 1' do
        let(:command) { ruby_command <<~COMMAND }
          puts 'stdout output'
          STDERR.puts 'stderr output'
          exit 1
        COMMAND

        let(:options) { { raise_errors: false, out: StringIO.new, err: StringIO.new } }

        it 'is not expected to raise an error' do
          expect { subject }.not_to raise_error
        end

        it 'is expected to return an a Result' do
          expect(subject).to be_a(ProcessExecuter::Result)
          expect(subject).to have_attributes(success?: false, exitstatus: 1)
          expect(subject.stdout.gsub("\r\n", "\n")).to eq("stdout output\n")
          expect(subject.stderr.gsub("\r\n", "\n")).to eq("stderr output\n")
        end
      end

      context 'a command that times out' do
        let(:command) { 'sleep 1' }
        let(:options) { { raise_errors: false, timeout_after: 0.01 } }

        it 'is not expected to raise an error' do
          expect { subject }.not_to raise_error
        end

        it 'is expected to return a result' do
          expect(subject).to be_a(ProcessExecuter::Result)
          expect(subject).to have_attributes(success?: nil, timed_out?: true)
        end
      end

      context 'a command that exits due to an unhandled signal', if: !windows? do
        let(:command) { 'echo "Hello world" && kill -9 $$' }
        let(:options) { { raise_errors: false, out: StringIO.new, err: StringIO.new } }

        it 'is not expected to raise an error' do
          expect { subject }.not_to raise_error
        end

        it 'is expected to return a result' do
          expect(subject).to be_a(ProcessExecuter::Result)
          expect(subject).to have_attributes(signaled?: true, termsig: 9)
        end
      end
    end

    context 'with environment variables' do
      let(:existing_var) { ENV.find { |_k, v| v.size > 3 && v.size < 10 && v.match(/^\w+$/) } }
      let(:env) { { 'VAR1' => 'val1', 'PATH' => ENV.fetch('PATH', nil) } }

      let(:command) { [env, *ruby_command(<<~COMMAND)] }
        new_val = ENV.fetch('VAR1')
        existing_val = ENV.fetch('#{existing_var[0]}', '')
        puts "\#{new_val} \#{existing_val}"
      COMMAND

      context 'when adding environment variables' do
        it 'is expected to add those variables in the environment' do
          expect(subject.stdout.gsub("\r\n", "\n")).to eq("val1 #{existing_var[1]}\n")
        end
      end

      context 'when removing environment variables' do
        let(:env) { { 'VAR1' => 'val1', existing_var[0] => nil } }
        it 'is expected to remove those variables from the environment' do
          expect(subject.stdout.gsub("\r\n", "\n")).to eq("val1 \n")
        end
      end

      context 'when resetting the environment' do
        let(:command) { [env, *ruby_command(<<~COMMAND)] }
          print ENV.include?('#{existing_var[0]}')
        COMMAND

        let(:options) { { unsetenv_others: true, out: StringIO.new, err: StringIO.new } }

        it 'is expected to remove all existing variables from the environment and add the given variables' do
          expect(subject.stdout.gsub("\r\n", "\n")).to eq('false')
        end
      end
    end

    context 'running the command in a different directory' do
      before { @tmpdir = File.realpath(Dir.mktmpdir) }
      after { FileUtils.remove_entry(@tmpdir) }
      let(:command) { ['ruby', '-e', 'puts Dir.pwd'] }
      let(:options) { { chdir: @tmpdir, out: StringIO.new, err: StringIO.new } }
      it 'is expected to run the command in the specified directory' do
        expect(subject.stdout.gsub("\r\n", "\n")).to eq("#{@tmpdir}\n")
      end
    end

    context 'buffers are given for stdout and stderr' do
      let(:out) { StringIO.new }
      let(:err) { StringIO.new }
      let(:command) { ruby_command <<~COMMAND }
        puts 'stdout output'
        STDERR.puts 'stderr output'
      COMMAND
      let(:options) { { out: out, err: err } }
      it 'is expected to capture stdout and stderr to the given buffers' do
        subject
        expect(out.string.gsub("\r\n", "\n")).to eq("stdout output\n")
        expect(err.string.gsub("\r\n", "\n")).to eq("stderr output\n")
      end
    end

    context 'when a file is given to capture stdout and stderr' do
      let(:out) { File.open('stdout.txt', 'w') }
      let(:err) { File.open('stderr.txt', 'w') }
      let(:command) { ruby_command <<~COMMAND }
        puts 'stdout output'
        STDERR.puts 'stderr output'
      COMMAND
      let(:options) { { out: out, err: err } }

      it 'is expected to capture stdout to the file and stderr to the buffer' do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            subject
            out.close
            err.close
            expect(File.read('stdout.txt').gsub("\r\n", "\n")).to eq("stdout output\n")
            expect(File.read('stderr.txt').gsub("\r\n", "\n")).to eq("stderr output\n")
          end
        end
      end
    end

    context 'when a pipe exception occurs' do
      before do
        allow_any_instance_of(ProcessExecuter::MonitoredPipe).to(
          receive(:exception).and_return(StandardError.new('pipe error'))
        )
      end

      subject { ProcessExecuter.run('echo Hello', out: StringIO.new, err: StringIO.new) }

      it 'is expected to raise ProcessExecuter::ProcessIOError' do
        expect { subject }.to raise_error(ProcessExecuter::ProcessIOError)
      end
    end

    context 'when given a logger' do
      let(:logger) { Logger.new(log_buffer, level: log_level) }
      let(:log_buffer) { StringIO.new }

      context 'a command that returns exitstatus 0' do
        let(:command) { ruby_command <<~COMMAND }
          puts 'stdout output'
          STDERR.puts 'stderr output'
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
          it 'is expected to log the command and its status AND the command stdout and stderr' do
            subject
            expect(log_buffer.string).to match(/INFO -- : \[.*?\] exited with status pid \d+ exit 0$/)
            expect(log_buffer.string.gsub("\r\n", "\n").gsub('\r\n', '\n')).to(
              match(/DEBUG -- : stdout:\n"stdout output\\n"\nstderr:\n"stderr output\\n"$/)
            )
          end
        end
      end

      context 'a command that returns exitstatus 1' do
        let(:command) { 'echo "stdout output" && echo "stderr output" 1>&2 && exit 1' }
        let(:options) { { raise_errors: false, out: StringIO.new, err: StringIO.new } }

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
        let(:options) { { raise_errors: false, timeout_after: 0.01 } }

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
              if jruby?
                /INFO -- : \[.*?\] exited with status pid \d+ KILL \(signal 9\) timed out after 0.01s$/
              elsif truffleruby?
                /INFO -- : \[.*?\] exited with status pid \d+ exit nil timed out after 0.01s$/
              elsif windows?
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

    context 'when given multiple destinations for stdout' do
      let(:command) { ruby_command <<~COMMAND }
        puts 'Test output'
      COMMAND

      it 'is expected to write stdout output to all destinations' do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            out_buffer = StringIO.new
            out_file = File.open('stdout.txt', 'w')
            ProcessExecuter.run(*command, out: [:tee, out_buffer, out_file])
            out_file.close
            expect(out_buffer.string.gsub("\r\n", "\n")).to eq("Test output\n")
            expect(File.read('stdout.txt').gsub("\r\n", "\n")).to eq("Test output\n")
          end
        end
      end
    end

    describe 'capturing stdout and stderr' do
      context "when given { out: 'stdout.txt' }" do
        let(:command) { ruby_command "STDOUT.puts 'stdout output'" }
        let(:options) { { out: 'stdout.txt' } }
        it 'should capture stdout to the stdout.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stdout.txt').gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end
      end

      context "when given { 1: 'stdout.txt' }" do
        let(:command) { ruby_command "STDOUT.puts 'stdout output'" }
        let(:options) { { 1 => 'stdout.txt' } }
        it 'should capture stdout to the stdout.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stdout.txt').gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end
      end

      context "when given { STDOUT => 'stdout.txt' }" do
        let(:command) { ruby_command "STDOUT.puts 'stdout output'" }
        let(:options) { { $stdout => 'stdout.txt' } }
        it 'should capture stdout to the stdout.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stdout.txt').gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end
      end

      context "when given { err: 'stderr.txt' }" do
        let(:command) { ruby_command "STDERR.puts 'stderr output'" }
        let(:options) { { err: 'stderr.txt' } }
        it 'should capture stderr to the stderr.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stderr.txt').gsub("\r\n", "\n")).to eq("stderr output\n")
            end
          end
        end
      end

      context "when given { 2 => 'stderr.txt' }" do
        let(:command) { ruby_command "STDERR.puts 'stderr output'" }
        let(:options) { { 2 => 'stderr.txt' } }
        it 'should capture stderr to the stderr.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stderr.txt').gsub("\r\n", "\n")).to eq("stderr output\n")
            end
          end
        end
      end

      context "when given { STDERR => 'stderr.txt' }" do
        let(:command) { ruby_command "STDERR.puts 'stderr output'" }
        let(:options) { { $stderr => 'stderr.txt' } }
        it 'should capture stderr to the stderr.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stderr.txt').gsub("\r\n", "\n")).to eq("stderr output\n")
            end
          end
        end
      end

      context "when given { out: 'stdout.txt', err: 'stderr.txt' }" do
        let(:command) { ruby_command "STDOUT.puts 'stdout output'; STDERR.puts 'stderr output'" }
        let(:options) { { out: 'stdout.txt', err: 'stderr.txt' } }

        it 'should capture stdout to the stdout.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stdout.txt').gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end

        it 'should capture stderr to the stderr.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('stderr.txt').gsub("\r\n", "\n")).to eq("stderr output\n")
            end
          end
        end
      end

      context "when given { [1, 2] => 'output.txt' }" do
        let(:command) { ruby_command "STDOUT.puts 'stdout output'; STDERR.puts 'stderr output'" }
        let(:options) { { [1, 2] => 'output.txt' } }
        it 'should capture both stdout and stderr to output.txt' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              ProcessExecuter.run(*command, **options)
              expect(File.read('output.txt').gsub("\r\n", "\n")).to match(/^stdout output\n/)
              expect(File.read('output.txt').gsub("\r\n", "\n")).to match(/^stderr output\n/)
            end
          end
        end
      end
    end

    describe 'when the destination is [:child, fd]', if: !windows? && !truffleruby? do
      it 'should capture the redirected output' do
        command = ruby_command(<<~RUBY)
          STDOUT.puts 'stdout output'
          STDERR.puts 'stderr output'
        RUBY

        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            file = File.open('output.txt', 'w')
            options = { out: [:child, 6], err: [:child, 6], 6 => file }
            ProcessExecuter.run(*command, **options)
            file.close

            expect(File.read('output.txt').gsub("\r\n", "\n")).to match(/^stdout output\n/)
            expect(File.read('output.txt').gsub("\r\n", "\n")).to match(/^stderr output\n/)
          end
        end
      end
    end

    describe 'when the destination is [:close]', if: !windows? && !truffleruby? && !jruby? do
      it 'should capture the redirected output' do
        command = ruby_command(<<~RUBY)
          STDOUT.puts 'stdout output'
          STDERR.puts 'stderr output'
        RUBY

        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            file = File.open('output.txt', 'w')
            options = { out: :close, err: file }

            result = ProcessExecuter.run(*command, **options)
            file.close

            expect(result.stdout).to be_nil
            expect(File.read('output.txt').gsub("\r\n", "\n")).to match(/^stderr output\n/)
          end
        end
      end
    end

    describe 'Raises a SpawnError if Process.spawn raises an error' do
      subject { ProcessExecuter.run(*command, **options, out: StringIO.new, err: StringIO.new) }
      let(:command) { ['echo hello'] }
      let(:options) { {} }

      context 'with an invalid command' do
        let(:command) { ['invalid_command'] }

        it 'should raise a ProcessExecuter::SpawnError' do
          expect { subject }.to raise_error(ProcessExecuter::SpawnError)
        end
      end

      context 'when the chdir option is a path to a non-existant directory' do
        let(:options) { { chdir: '/invalid/path/to/dir' } }

        context 'when run with MRI, non-Windows', if: mri? && !windows? do
          it 'is expected to raise an error' do
            expect { subject }.to raise_error(ProcessExecuter::SpawnError)
          end
        end

        context 'when run with MRI on Windows', if: mri? && windows? do
          # For Windoes MRI, when ProcessExecuter.run is given bad path for the
          # `chdir:` option, the test hangs when Process.spawn is called.

          # This only happens when out or err is redirected and wrapped in a
          # MonitoredPipe.

          it 'is expected to raise an error', skip: 'this test hangs, see comment' do
            expect { subject }.to raise_error(ProcessExecuter::SpawnError)
          end
        end

        # TruffleRuby does not raise errors in the same cases as MRI (see
        # oracle/truffleruby#3825)
        #
        context 'when run with TruffleRuby', if: truffleruby? do
          it 'is expected to return a Result with exitstatus 1 (which raises a FailedError)' do
            expect { subject }.to raise_error(ProcessExecuter::FailedError)
          end
        end

        # JRuby silently ignores the chdir option
        #
        context 'when run with JRuby', if: jruby? do
          it 'is expected to ignore the invalid chdir path' do
            expect(subject).to be_a(ProcessExecuter::Result).and have_attributes(exitstatus: 0)
          end
        end
      end
    end
  end
end
