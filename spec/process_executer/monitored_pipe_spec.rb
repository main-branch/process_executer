# frozen_string_literal: true

require 'tmpdir'

RSpec.describe ProcessExecuter::MonitoredPipe do
  # Tear down a pipe whose threads are wedged so that a deadlock fails this
  # example instead of hanging the whole suite (including the global
  # `assert_no_open_instances` hook).
  # Every step is a no-op when the pipe already closed normally, so this is safe
  # to call unconditionally: killing a dead thread does nothing, the fds are
  # guarded by #closed?, and remove_open_instance deletes a key that may not be
  # there.
  def force_close(pipe, *threads)
    threads.compact.each(&:kill)
    pipe.thread.kill
    pipe.pipe_writer.close unless pipe.pipe_writer.closed?
    pipe.pipe_reader.close unless pipe.pipe_reader.closed?
    described_class.remove_open_instance(pipe)
  end

  let(:monitored_pipe) { described_class.new(destination) }
  let(:output_writer) { StringIO.new }
  let(:destination) { output_writer }

  context 'when used to wrap an output destination for Process.spawn' do
    context 'when the output destination is nil' do
      let(:destination) { nil }
      it 'should raise an ProcessExecuter::ArgumentError' do
        expect { ProcessExecuter::MonitoredPipe.new(nil) }.to(
          raise_error(ProcessExecuter::ArgumentError, 'Destination nil is not compatible with MonitoredPipe')
        )
      end
    end

    context 'when the output destination is an fd' do
      it 'should write output to the fd' do
        command = ruby_command(<<~COMMAND)
          puts 'stdout output'
        COMMAND
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'output.txt')
          File.open(path, 'w', 0o644) do |f|
            fd = f.fileno
            monitored_pipe = ProcessExecuter::MonitoredPipe.new(fd)
            _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
            monitored_pipe.close

            expect(monitored_pipe.exception).to be_nil
            expect(status.exitstatus).to eq(0)
          end
          expect(File.read(path).gsub("\r\n", "\n")).to eq("stdout output\n")
        end
      end
    end

    context 'when the output destination is a Symbol' do
      context 'when the output destination is :out' do
        it 'should write output to STDERR in the child to STDOUT in the parent' do
          command = ruby_command(<<~COMMAND)
            $stderr.puts 'child stderr output'
          COMMAND
          monitored_pipe = ProcessExecuter::MonitoredPipe.new(:out)

          stdout_buffer = StringIO.new
          saved_stdout = $stdout
          $stdout = stdout_buffer

          _pid, status = Process.wait2(Process.spawn(*command, err: monitored_pipe))
          monitored_pipe.close

          $stdout = saved_stdout

          expect(monitored_pipe.exception).to be_nil
          expect(status.exitstatus).to eq(0)
          expect(stdout_buffer.string.gsub("\r\n", "\n")).to eq("child stderr output\n")
        end
      end

      context 'when the output destination is :err' do
        it 'should write the child\'s STDOUT to the parent\'s STDERR' do
          command = ruby_command(<<~COMMAND)
            puts 'child stdout output'
          COMMAND
          monitored_pipe = ProcessExecuter::MonitoredPipe.new(:err)

          stderr_buffer = StringIO.new
          saved_stderr = $stderr
          $stderr = stderr_buffer

          _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
          monitored_pipe.close

          $stderr = saved_stderr

          expect(monitored_pipe.exception).to be_nil
          expect(status.exitstatus).to eq(0)
          expect(stderr_buffer.string.gsub("\r\n", "\n")).to eq("child stdout output\n")
        end
      end
    end

    context 'when the output destination is a File opened for writing' do
      it 'should write output to the file and not close the file' do
        command = ruby_command(<<~COMMAND)
          puts 'stdout output'
        COMMAND

        Dir.mktmpdir do |dir|
          path = File.join(dir, 'output.txt')
          File.open(path, 'w', 0o644) do |f|
            monitored_pipe = ProcessExecuter::MonitoredPipe.new(f)
            _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
            monitored_pipe.close

            expect(monitored_pipe.exception).to be_nil
            expect(status.exitstatus).to eq(0)
            expect(f.closed?).to eq(false)
          end

          expect(File.read(path).gsub("\r\n", "\n")).to eq("stdout output\n")
        end
      end
    end

    context 'when the output destination is a filepath' do
      context 'when the filepath does not exist' do
        it 'should create the file with 0644 perms and write output to the file' do
          command = ruby_command(<<~COMMAND)
            puts 'stdout output'
          COMMAND

          Dir.mktmpdir do |dir|
            filepath = File.join(dir, 'output.txt')
            monitored_pipe = ProcessExecuter::MonitoredPipe.new(filepath)
            _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
            monitored_pipe.close

            expect(monitored_pipe.exception).to be_nil
            expect(status.exitstatus).to eq(0)
            unless windows?
              file_permissions = File.stat(filepath).mode & 0o7777
              expect(file_permissions).to eq(0o644)
            end
            expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
          end
        end
      end

      context 'when the filepath exists' do
        it 'should overrite the file with the output and not change the file perms' do
          command = ruby_command(<<~COMMAND)
            puts 'stdout output'
          COMMAND

          Dir.mktmpdir do |dir|
            filepath = File.join(dir, 'output.txt')

            File.open(filepath, 'w', 0o600) do |f|
              f.puts 'initial content'
              f.close

              monitored_pipe = ProcessExecuter::MonitoredPipe.new(filepath)
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)
            end

            unless windows?
              file_permissions = File.stat(filepath).mode & 0o7777
              expect(file_permissions).to eq(0o600)
            end
            expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
          end
        end
      end
    end

    context 'when the output destination is an array in the form [filepath]' do
      # [filepath] only works for stdin
      it 'should raise an ProcessExecuter::ArgumentError' do
        expect { ProcessExecuter::MonitoredPipe.new(['filepath']) }.to(
          raise_error(ProcessExecuter::ArgumentError, 'Destination ["filepath"] is not compatible with MonitoredPipe')
        )
      end
    end

    context 'when the output destination is an array in the form [filepath, mode]' do
      context 'when mode is "r"' do
        before do
          ProcessExecuter::MonitoredPipe.assert_no_open_instances
        end

        after do
          ProcessExecuter::MonitoredPipe.assert_no_open_instances
        end

        it 'the exception methods should note that an IOError was raised' do
          command = ruby_command(<<~COMMAND)
            puts 'stdout output'
          COMMAND
          Dir.mktmpdir do |dir|
            filepath = File.join(dir, 'output.txt')
            File.write(filepath, 'initial content')
            monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'r'])
            begin
              _pid, _status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
            ensure
              monitored_pipe.close
            end

            # We should try to model what happens in this command:
            #
            #   pid, status = Process.wait2(Process.spawn(*command, out: ['output.txt', 'r']))
            #
            # This command returns a status with exitstatus == 1 and outputs "echo:
            # fflush: Bad file descriptor" to stderr
            #
            # However, the current implementation does this (which I think is reasonable):
            #
            expect(monitored_pipe.exception.inspect).to eq('#<IOError: not opened for writing>')
          end
        end
      end

      context 'when mode is "w"' do
        context 'when the filepath does not exist' do
          it 'should create the file with perms 0o644 and write output to the file' do
            command = ruby_command(<<~COMMAND)
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'w'])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o644)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end

        context 'when the filepath exists' do
          it 'should overrite the file with the output and not change the file perms' do
            command = ruby_command(<<~COMMAND)
              # Suppresses conversion between EOL and CRLF
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              File.open(filepath, 'w', 0o600) { |f| f.puts 'initial content' }

              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'w'])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o600)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end
      end

      context 'when mode is "a"' do
        context 'when the filepath does not exist' do
          it 'should create the file with 0o644 perms and write output to the file' do
            command = ruby_command(<<~COMMAND)
              # Suppresses conversion between EOL and CRLF
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'a'])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o644)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end

        context 'when the filepath exists' do
          it 'should append the output to the file and not change the file perms' do
            command = ruby_command(<<~COMMAND)
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              File.open(filepath, 'w', 0o600) { |f| f.puts 'initial content' }

              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'a'])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o600)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("initial content\nstdout output\n")
            end
          end
        end
      end
    end

    context 'when the output destination is an array in the form [filepath, mode, perm]' do
      context 'when mode is "w"' do
        context 'when the filepath does not exist' do
          it 'should create the file with the given perms and write output to the file' do
            command = ruby_command(<<~COMMAND)
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'w', 0o600])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o600)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end
        context 'when the filepath exists' do
          it 'should overrite the file with the output and not chnage the file perms' do
            command = ruby_command(<<~COMMAND)
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              File.open(filepath, 'w', 0o600) { |f| f.puts 'initial content' }

              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'w', 0o644])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o600)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end
      end

      context 'when mode is "a"' do
        context 'when the filepath does not exist' do
          it 'should create the file with the given perms and write output to the file' do
            command = ruby_command(<<~COMMAND)
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'a', 0o600])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o600)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("stdout output\n")
            end
          end
        end

        context 'when the filepath exists' do
          it 'should append the output to the file and not change the file perms' do
            command = ruby_command(<<~COMMAND)
              puts 'stdout output'
            COMMAND

            Dir.mktmpdir do |dir|
              filepath = File.join(dir, 'output.txt')
              File.open(filepath, 'w', 0o600) { |f| f.puts 'initial content' }

              monitored_pipe = ProcessExecuter::MonitoredPipe.new([filepath, 'a', 0o644])
              _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
              monitored_pipe.close

              expect(monitored_pipe.exception).to be_nil
              expect(status.exitstatus).to eq(0)

              unless windows?
                file_permissions = File.stat(filepath).mode & 0o7777
                expect(file_permissions).to eq(0o600)
              end
              expect(File.read(filepath).gsub("\r\n", "\n")).to eq("initial content\nstdout output\n")
            end
          end
        end
      end
    end

    context 'when the output destination is an array in the form [:child, fd]' do
      # redirect the source to the destination fd in the child process
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { ProcessExecuter::MonitoredPipe.new([:child, 1]) }.to(
          raise_error(ProcessExecuter::ArgumentError, 'Destination [:child, 1] is not compatible with MonitoredPipe')
        )
      end
    end

    context 'when the output destination is :close' do
      # close the fd in the child process
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { ProcessExecuter::MonitoredPipe.new(:close) }.to(
          raise_error(ProcessExecuter::ArgumentError, 'Destination :close is not compatible with MonitoredPipe')
        )
      end
    end

    context 'when the output destination is an object that responds to #write but not #fileno' do
      it 'should write output to the object' do
        output_writer = StringIO.new
        monitored_pipe = ProcessExecuter::MonitoredPipe.new(output_writer)
        command = ruby_command(<<~COMMAND)
          puts 'stdout output'
        COMMAND
        _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
        monitored_pipe.close
        expect(monitored_pipe.exception).to be_nil
        expect(status.exitstatus).to eq(0)
        expect(output_writer.string.gsub("\r\n", "\n")).to eq("stdout output\n")
      end
    end

    context 'when the output destination is another monitored pipe' do
      it 'should write output to the other monitored pipe' do
        output_writer = StringIO.new
        monitored_pipe1 = ProcessExecuter::MonitoredPipe.new(output_writer)
        monitored_pipe2 = ProcessExecuter::MonitoredPipe.new(monitored_pipe1)
        command = ruby_command(<<~COMMAND)
          puts 'stdout output'
        COMMAND
        _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe2))
        monitored_pipe2.close
        monitored_pipe1.close
        expect(monitored_pipe1.exception).to be_nil
        expect(monitored_pipe2.exception).to be_nil
        expect(status.exitstatus).to eq(0)
        expect(output_writer.string.gsub("\r\n", "\n")).to eq("stdout output\n")
      end
    end

    context 'when the output destination is an array of objects containing one or more of: ' \
            'fd, File opened for writing, filepath, [filepath, mode], [filepath, mode, perms],
            and objects responding to #write but not #fileno' do
      it 'should write output to all the objects' do
        Dir.mktmpdir do |dir|
          destination1 = File.join(dir, 'output1.txt')
          filepath2 = File.join(dir, 'output2.txt')
          destination3 = StringIO.new

          File.open(filepath2, 'w', 0o644) do |destination2|
            monitored_pipe = ProcessExecuter::MonitoredPipe.new([:tee, destination1, destination2, destination3])

            command = ruby_command(<<~COMMAND)
              puts 'stdout output'
            COMMAND
            _pid, status = Process.wait2(Process.spawn(*command, out: monitored_pipe))
            monitored_pipe.close

            expect(monitored_pipe.exception).to be_nil
            expect(status.exitstatus).to eq(0)
          end

          expect(File.read(destination1).gsub("\r\n", "\n")).to eq("stdout output\n")
          expect(File.read(filepath2).gsub("\r\n", "\n")).to eq("stdout output\n")
          expect(destination3.string.gsub("\r\n", "\n")).to eq("stdout output\n")
        end
      end
    end
  end

  describe '#initialize' do
    after { monitored_pipe.close }

    it 'should create a new monitored pipe' do
      expect(monitored_pipe).to have_attributes(
        thread: Thread,
        destination: ProcessExecuter::Destinations::DestinationBase,
        pipe_reader: IO,
        pipe_writer: IO,
        chunk_size: Integer
      )
    end

    it 'should start a thread to monitor the pipe' do
      expect(monitored_pipe.thread.alive?).to eq(true)
    end

    it 'should set the state to :open' do
      expect(monitored_pipe.state).to eq(:open)
    end
  end

  describe '#close' do
    it 'should eventually kill the thread' do
      monitored_pipe.close

      # Give the thread time to die (up to 1 second)
      thread_dead = false
      10.times do
        thread_dead = !monitored_pipe.thread.alive?
        break if thread_dead

        # :nocov: this code is not guaranteed to be run
        sleep(0.01)
        # :nocov:
      end

      expect(thread_dead).to eq(true)
    end

    it 'should set the state to closed' do
      monitored_pipe.close
      expect(monitored_pipe.state).to eq(:closed)
    end

    it 'should be ok to call two or more times' do
      monitored_pipe.close
      expect { monitored_pipe.close }.not_to raise_error
    end
  end

  describe '#to_io' do
    subject { monitored_pipe.to_io }
    after { monitored_pipe.close }
    it 'should return the pipe writer' do
      expect(subject).to eq(monitored_pipe.pipe_writer)
    end
  end

  describe '#fileno' do
    subject { monitored_pipe.fileno }
    after { monitored_pipe.close }
    it 'should return the file descriptor for the pipe writer' do
      expect(subject).to eq(monitored_pipe.pipe_writer.fileno)
    end
  end

  describe '#write' do
    it 'should write to the destination' do
      monitored_pipe.write('hello')
      monitored_pipe.write(' ')
      monitored_pipe.write('world')
      monitored_pipe.close
      expect(output_writer.string).to eq('hello world')
    end

    context 'with a file descriptor to an open file' do
      it 'should write to the file descriptor' do
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'output.txt')
          File.open(path, 'w') do |file|
            pid = Process.spawn('echo hello', out: file.fileno)
            Process.wait(pid)
          end

          expect(File.read(path)).to eq("hello\n")
        end
      end
    end

    context 'with a file descriptor to an open file' do
      let(:destination) { @file.fileno }

      it 'should write to the file descriptor' do
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'output.txt')
          @file = File.open(path, 'w')
          monitored_pipe.write('hello')
          monitored_pipe.write(' ')
          monitored_pipe.write('world')
          sleep 0.5
          monitored_pipe.close
          @file.close
          expect(File.read(path)).to eq('hello world')
        end
      end
    end

    context 'with :out' do
      let(:destination) { :out }

      it 'should write to STDOUT' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
          monitored_pipe.close
        end.to output("hello world\n").to_stdout
      end
    end

    context 'with 1' do
      let(:destination) { 1 }

      it 'should write to STDOUT' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
          monitored_pipe.close
        end.to output("hello world\n").to_stdout
      end
    end

    context 'with :err' do
      let(:destination) { :err }

      it 'should write to STDERR' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
          monitored_pipe.close
        end.to output("hello world\n").to_stderr
      end
    end

    context 'with 2' do
      let(:destination) { 2 }

      it 'should write to STDERR' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
          monitored_pipe.close
        end.to output("hello world\n").to_stderr
      end
    end

    context 'when there is time between the writes to the pipe' do
      it 'should write to the writer' do
        monitored_pipe.write('hello')
        sleep 0.01
        monitored_pipe.write(' ')
        sleep 0.01
        monitored_pipe.write('world')
        sleep 0.01
        monitored_pipe.close
        expect(output_writer.string).to eq('hello world')
      end
    end

    context 'when there is a delay before the first write to the pipe' do
      it 'should write to the writer' do
        sleep 0.1
        monitored_pipe.write('hello')
        monitored_pipe.write(' ')
        monitored_pipe.write('world')
        sleep 0.01
        monitored_pipe.close
        expect(output_writer.string).to eq('hello world')
      end
    end

    context 'when there is a delay after the last write to the pipe' do
      it 'should write to the writer' do
        monitored_pipe.write('hello')
        monitored_pipe.write(' ')
        monitored_pipe.write('world')
        sleep 0.1
        monitored_pipe.close
        expect(output_writer.string).to eq('hello world')
      end
    end

    context 'with a large amount of data' do
      it 'should write all the data to the writer' do
        data = 'h' * 50_000_000
        monitored_pipe.write(data)
        monitored_pipe.close
        expect(output_writer.string.size).to eq(data.size)
      end
    end

    context 'when the destination raises an error while the pipe buffer is full' do
      let(:output_writer) { double('output') }

      # Much larger than the OS pipe buffer (~64KB) so that the write to the pipe
      # blocks partway through while the destination is raising on an earlier chunk.
      let(:data) { 'x' * 10_000_000 }

      before { allow(output_writer).to receive(:write).and_raise(RuntimeError, 'destination failed') }

      it 'should not deadlock the writing thread and the monitoring thread' do
        # The thread returns whatever #write does: the error it raised, or the
        # number of bytes written if it unexpectedly ran to completion.
        writer = Thread.new do
          monitored_pipe.write(data)
        rescue StandardError => e
          e
        end

        # Do not call writer.value before this expectation: it waits on the thread,
        # which never finishes if the deadlock has come back.
        expect(writer.join(10)).not_to be_nil, '#write deadlocked with the monitoring thread'

        # The monitoring thread closes the pipe when the destination raises, so the
        # write that is still in progress fails. #write reports that as an IOError
        # on every engine; the message is engine-specific, so only the class is
        # asserted here.
        expect(writer.value).to be_a(IOError)

        monitored_pipe.close
        expect(monitored_pipe.state).to eq(:closed)
        expect(monitored_pipe.exception).to be_a(RuntimeError)
      ensure
        # Leave no open pipe behind no matter which expectation above failed. The
        # suite asserts after every example that no MonitoredPipe is still open, so
        # a pipe leaked here fails this example and every example that follows it.
        #
        # This runs unconditionally. The state is not a safe signal that cleanup
        # already happened: the monitoring thread sets the state to :closed on its
        # own when the destination raises, but only #close untracks the instance.
        force_close(monitored_pipe, writer)
      end
    end

    context 'when a writer raises an exception' do
      let(:output_writer) { double('output') }

      # Much larger than the OS pipe buffer (~64KB) so that the write to the pipe
      # is guaranteed to still be blocked when the monitoring thread reads the
      # first chunk, hits the destination error, and closes the pipe.
      let(:data) { 'x' * 10_000_000 }

      before do
        expect(output_writer).to receive(:write).and_raise(
          Encoding::UndefinedConversionError, 'UTF-8 conversion error'
        )
      end
      let(:destination) { output_writer }

      it 'should eventually kill the monitoring thread' do
        begin
          monitored_pipe.write(data)
        rescue IOError
          # The monitoring thread hit the destination error and closed the pipe
          # while the write was still in progress; a documented #write outcome.
        end
        sleep(0.01)
        monitored_pipe.close
        expect(monitored_pipe.thread.alive?).to eq(false)
      ensure
        # Leave no open pipe behind no matter which expectation above failed. The
        # monitoring thread sets the state to :closed on its own when the
        # destination raises, but only #close untracks the instance, so a failure
        # before #close would otherwise cascade into every following example.
        force_close(monitored_pipe)
      end

      it 'should eventually set the state to :closed' do
        begin
          monitored_pipe.write(data)
        rescue IOError
          # The monitoring thread hit the destination error and closed the pipe
          # while the write was still in progress; a documented #write outcome.
        end
        sleep(0.01)
        monitored_pipe.close
        expect(monitored_pipe.state).to eq(:closed)
      ensure
        # Leave no open pipe behind no matter which expectation above failed. The
        # monitoring thread sets the state to :closed on its own when the
        # destination raises, but only #close untracks the instance, so a failure
        # before #close would otherwise cascade into every following example.
        force_close(monitored_pipe)
      end

      it 'should eventually save the exception raised to #exception' do
        begin
          monitored_pipe.write(data)
        rescue IOError
          # The monitoring thread hit the destination error and closed the pipe
          # while the write was still in progress; a documented #write outcome.
        end
        sleep(0.01)
        monitored_pipe.close
        expect(monitored_pipe.exception).to be_a(Encoding::UndefinedConversionError)
        expect(monitored_pipe.exception.message).to eq('UTF-8 conversion error')
      ensure
        # Leave no open pipe behind no matter which expectation above failed. The
        # monitoring thread sets the state to :closed on its own when the
        # destination raises, but only #close untracks the instance, so a failure
        # before #close would otherwise cascade into every following example.
        force_close(monitored_pipe)
      end

      it 'should raise an exception if #write is called after the pipe is closed' do
        begin
          monitored_pipe.write(data)
        rescue IOError
          # The monitoring thread hit the destination error and closed the pipe
          # while the write was still in progress; a documented #write outcome.
        end
        sleep(0.01)
        monitored_pipe.close
        expect { monitored_pipe.write('world') }.to raise_error(IOError, 'closed stream')
      ensure
        # Leave no open pipe behind no matter which expectation above failed. The
        # monitoring thread sets the state to :closed on its own when the
        # destination raises, but only #close untracks the instance, so a failure
        # before #close would otherwise cascade into every following example.
        force_close(monitored_pipe)
      end
    end

    context 'after the pipe is closed' do
      it 'should raise an exception' do
        monitored_pipe.close
        expect { monitored_pipe.write('hello') }.to raise_error(IOError, 'closed stream')
      end
    end
  end

  describe 'encoding of output' do
    let(:output_writer) do
      Class.new do
        def initialize
          @data = []
        end

        attr_reader :data

        def write(new_data)
          @data << new_data
        end
      end.new
    end

    it 'should write data with BINARY encoding' do
      monitored_pipe.write('違いを生み出すサンプルテキスト'.encode(Encoding::UTF_8))
      sleep(0.01)
      monitored_pipe.close
      expect(output_writer.data.size).to eq(1)
      expect(output_writer.data).to all(satisfy { |d| d.encoding == Encoding::BINARY })
    end
  end
end
