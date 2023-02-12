# frozen_string_literal: true

RSpec.describe ProcessExecuter::MonitoredPipe do
  let(:monitored_pipe) { described_class.new(*writers) }
  let(:output) { StringIO.new }
  let(:writers) { [output] }

  describe '#initialize' do
    after { monitored_pipe.close }

    it 'should create a new monitored pipe' do
      # SimpleCov in JRuby reports the following line as not covered even though it is
      # :nocov:
      expect(monitored_pipe).to have_attributes(
        thread: Thread, writers: writers, pipe_reader: IO, pipe_writer: IO, chunk_size: 100_000
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
    it 'should kill the thread' do
      monitored_pipe.close
      expect(monitored_pipe.thread.alive?).to eq(false)
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
        expect(output.string).to eq('hello world')
      end
    end

    context 'with multiple writers' do
      let(:output1) { StringIO.new }
      let(:output2) { StringIO.new }
      let(:writers) { [output1, output2] }
      it 'should write to the writers' do
        monitored_pipe.write('hello')
        monitored_pipe.write(' ')
        monitored_pipe.write('world')
        monitored_pipe.close
        expect(output1.string).to eq('hello world')
        expect(output2.string).to eq('hello world')
      end
    end

    # Make sure that all code paths are covered by the tests
    context 'when there is time between the writes to the pipe' do
      it 'should write to the writer' do
        monitored_pipe.write('hello')
        sleep 0.1
        monitored_pipe.write(' ')
        sleep 0.1
        monitored_pipe.write('world')
        monitored_pipe.close
        expect(output.string).to eq('hello world')
      end
    end

    # Make sure that all code paths are covered by the tests
    context 'when there is a delay before the first write to the pipe' do
      it 'should write to the writer' do
        sleep 0.1
        monitored_pipe.write('hello')
        monitored_pipe.write(' ')
        sleep 0.1
        monitored_pipe.write('world')
        monitored_pipe.close
        expect(output.string).to eq('hello world')
      end
    end

    # Make sure that all code paths are covered by the tests
    context 'when there is a delay after the last write to the pipe' do
      it 'should write to the writer' do
        monitored_pipe.write('hello')
        monitored_pipe.write(' ')
        sleep 0.1
        monitored_pipe.write('world')
        sleep 0.2
        monitored_pipe.close
        expect(output.string).to eq('hello world')
      end
    end

    context 'with a large amount of data' do
      it 'should write all the data to the writer' do
        data = 'h' * 50_000_000
        monitored_pipe.write(data)
        monitored_pipe.close
        expect(output.string.size).to eq(data.size)
      end
    end

    context 'when a writer raises an exception' do
      let(:output) { double('output') }
      before do
        expect(output).to receive(:write).with('hello').and_raise(
          Encoding::UndefinedConversionError, 'UTF-8 conversion error'
        )
      end
      let(:writers) { [output] }

      it 'should kill the monitoring thread' do
        monitored_pipe.write('hello')
        sleep(0.02)
        expect(monitored_pipe.thread.alive?).to eq(false)
      end

      it 'should set the state to :closed' do
        monitored_pipe.write('hello')
        sleep(0.02)
        expect(monitored_pipe.state).to eq(:closed)
      end

      it 'should save the exception raised to #exception' do
        monitored_pipe.write('hello')
        sleep(0.02)
        expect(monitored_pipe.exception).to be_a(Encoding::UndefinedConversionError)
        expect(monitored_pipe.exception.message).to eq('UTF-8 conversion error')
      end

      it 'should raise an exception if #write is called after the pipe is closed' do
        monitored_pipe.write('hello')
        sleep(0.02)
        expect { monitored_pipe.write('world') }.to raise_error(IOError, 'closed stream')
      end
    end
  end
end
