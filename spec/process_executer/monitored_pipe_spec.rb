# frozen_string_literal: true

require 'tmpdir'

RSpec.describe ProcessExecuter::MonitoredPipe do
  let(:monitored_pipe) { described_class.new(*writers) }
  let(:output_writer) { StringIO.new }
  let(:writers) { [output_writer] }

  describe '#initialize' do
    after { monitored_pipe.close }

    it 'should create a new monitored pipe' do
      # SimpleCov in JRuby reports the following line as not covered even though it is
      # :nocov:
      expect(monitored_pipe).to have_attributes(
        thread: Thread, writers:, pipe_reader: IO, pipe_writer: IO, chunk_size: 100_000
      )
      # :nocov:
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
        # :nocov:
        thread_dead = !monitored_pipe.thread.alive?
        break if thread_dead

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
    context 'with a single writer' do
      it 'should write to the writer' do
        monitored_pipe.write('hello')
        monitored_pipe.write(' ')
        monitored_pipe.write('world')
        monitored_pipe.close
        expect(output_writer.string).to eq('hello world')
      end
    end

    context 'with multiple writers' do
      let(:output_writer1) { StringIO.new }
      let(:output_writer2) { StringIO.new }
      let(:writers) { [output_writer1, output_writer2] }
      it 'should write to the writers' do
        monitored_pipe.write('hello')
        monitored_pipe.write(' ')
        monitored_pipe.write('world')
        monitored_pipe.close
        expect(output_writer1.string).to eq('hello world')
        expect(output_writer2.string).to eq('hello world')
      end
    end

    context 'with a file descriptor to an open file' do
      it 'should write to the file descriptor' do
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'output.txt')
          file = File.open(path, 'w')
          pid = Process.spawn('echo hello', out: file.fileno)
          Process.wait(pid)
          file.close
          expect(File.read(path)).to eq("hello\n")
        end
      end
    end

    context 'with a file descriptor to an open file' do
      let(:writers) { [@file.fileno] }

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
      let(:writers) { [:out] }

      it 'should write to STDOUT' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
        end.to output("hello world\n").to_stdout
      end
    end

    context 'with 1' do
      let(:writers) { [1] }

      it 'should write to STDOUT' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
        end.to output("hello world\n").to_stdout
      end
    end

    context 'with :err' do
      let(:writers) { [:err] }

      it 'should write to STDERR' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
        end.to output("hello world\n").to_stderr
      end
    end

    context 'with 2' do
      let(:writers) { [2] }

      it 'should write to STDERR' do
        expect do
          monitored_pipe.write("hello world\n")
          sleep 0.01
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

    context 'when a writer raises an exception' do
      let(:output_writer) { double('output') }
      before do
        expect(output_writer).to receive(:write).with('hello').and_raise(
          Encoding::UndefinedConversionError, 'UTF-8 conversion error'
        )
      end
      let(:writers) { [output_writer] }

      it 'should eventually kill the monitoring thread' do
        monitored_pipe.write('hello')
        sleep(0.01)
        expect(monitored_pipe.thread.alive?).to eq(false)
      end

      it 'should eventually set the state to :closed' do
        monitored_pipe.write('hello')
        sleep(0.01)
        expect(monitored_pipe.state).to eq(:closed)
      end

      it 'should eventually save the exception raised to #exception' do
        monitored_pipe.write('hello')
        sleep(0.01)
        expect(monitored_pipe.exception).to be_a(Encoding::UndefinedConversionError)
        expect(monitored_pipe.exception.message).to eq('UTF-8 conversion error')
      end

      it 'should raise an exception if #write is called after the pipe is closed' do
        monitored_pipe.write('hello')
        sleep(0.01)
        expect { monitored_pipe.write('world') }.to raise_error(IOError, 'closed stream')
      end
    end

    context 'after the pipe is closed' do
      it 'should raise an exception' do
        monitored_pipe.close
        expect { monitored_pipe.write('hello') }.to raise_error(IOError, 'closed stream')
      end
    end
  end
end
