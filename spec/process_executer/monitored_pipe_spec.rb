# frozen_string_literal: true

RSpec.describe ProcessExecuter::MonitoredPipe do
  let(:monitored_pipe) { described_class.new(*writers) }
  let(:output) { StringIO.new }
  let(:writers) { [output] }

  describe '#initialize' do
    after { monitored_pipe.close }

    it 'should create a new monitored pipe' do
      expect(monitored_pipe).to have_attributes(thread: Thread, writers: writers, chunk_size: 1000)
    end

    it 'should start a thread to monitor the pipe' do
      expect(monitored_pipe.thread.alive?).to eq(true)
    end
  end

  describe '#close' do
    it 'should kill the thread' do
      monitored_pipe.close
      expect(monitored_pipe.thread.alive?).to eq(false)
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
  end
end
