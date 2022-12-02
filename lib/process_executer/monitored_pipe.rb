# frozen_string_literal: true

require 'stringio'
require 'io/wait'

module ProcessExecuter
  # Stream data sent through a pipe to one or more writers
  #
  # When a new MonitoredPipe is created, a pipe is created (via IO.pipe) and
  # a thread is created to read data written to the pipe.
  #
  # Data that is read from the pipe is written one or more writers passed to
  # `#initialize`.
  #
  # `#close` must be called to ensure that (1) the pipe is closed, (2) all data is
  # read from the pipe and written to the writers, and (3) the monitoring thread is
  # killed.
  #
  # @example Collect pipe data into a string
  #   pipe_data = StringIO.new
  #   begin
  #     pipe = MonitoredPipe.new(pipe_data)
  #     pipe.write("Hello World")
  #   ensure
  #     pipe.close
  #   end
  #   pipe_data.string #=> "Hello World"
  #
  # @example Collect pipe data into a string AND a file
  #   pipe_data_string = StringIO.new
  #   pipe_data_file = File.open("pipe_data.txt", "w")
  #   begin
  #     pipe = MonitoredPipe.new(pipe_data_string, pipe_data_file)
  #     pipe.write("Hello World")
  #   ensure
  #     pipe.close
  #   end
  #   pipe_data_string.string #=> "Hello World"
  #   File.read("pipe_data.txt") #=> "Hello World"
  #
  # @api public
  #
  class MonitoredPipe
    # Create a new monitored pipe
    #
    # Creates a IO.pipe and starts a monitoring thread to read data written to the pipe.
    #
    # @example
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #
    # @param writers [Array<#write>] as data is read from the pipe, it is written to these writers
    # @param chunk_size [Integer] the size of the chunks to read from the pipe
    #
    def initialize(*writers, chunk_size: 1000)
      @pipe_reader, @pipe_writer = IO.pipe
      @chunk_size = chunk_size
      @writers = writers
      @thread = Thread.new { monitor_pipe }
    end

    # Kill the monitoring thread, read remaining data, and close the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.write('Hello World')
    #   pipe.close
    #   data_collector.string #=> "Hello World"
    #
    # @return [void]
    #
    def close
      thread.kill
      thread.join
      pipe_writer.close
      read_pipe_output if pipe_reader.wait_readable(0)
      pipe_reader.close
    end

    # Return the write end of the pipe so that data can be written to it
    #
    # Data written to this end of the pipe will be read by the monitor thread and
    # written to the writers passed to `#initialize`.
    #
    # This is so we can provide a MonitoredPipe to Process.spawn as a FD
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.to_io.write('Hello World')
    #   pipe.close
    #   data_collector.string #=> "Hello World"
    #
    # @return [IO] the write end of the pipe
    #
    # @api private
    #
    def to_io
      pipe_writer
    end

    # @!attribute [r] fileno
    #
    # The file descriptor for the write end of the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.fileno == pipe.to_io.fileno #=> true
    #
    # @return [Integer] the file descriptor for the write end of the pipe
    #
    # @api private
    #
    def fileno
      pipe_writer.fileno
    end

    # Writes data to the pipe so that it can be read by the monitor thread
    #
    # Primarily used for testing.
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.write('Hello World')
    #   pipe.close
    #   data_collector.string #=> "Hello World"
    #
    # @param data [String] the data to write to the pipe
    #
    # @return [Integer] the number of bytes written to the pipe
    #
    # @api private
    #
    def write(data)
      pipe_writer.write(data)
    end

    # @!attribute [r]
    #
    # The size of the chunks to read from the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.chunk_size #=> 1000
    #
    # @return [Integer] the size of the chunks to read from the pipe
    #
    attr_reader :chunk_size

    # @!attribute [r]
    #
    # An array of writers to write data that is read from the pipe
    #
    # @example with one writer
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.writers #=> [data_collector]
    #
    # @example with an array of writers
    #   require 'stringio'
    #   data_collector1 = StringIO.new
    #   data_collector2 = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector1, data_collector2)
    #   pipe.writers #=> [data_collector1, data_collector2]]
    #
    # @return [Array<#write>]
    #
    attr_reader :writers

    # @!attribute [r]
    #
    # The thread that monitors the pipe
    #
    # @example
    #   require 'stringio'
    #   data_collector = StringIO.new
    #   pipe = ProcessExecuter::MonitoredPipe.new(data_collector)
    #   pipe.thread #=> #<Thread:0x00007f8b1a0b0e00>
    #
    # @return [Thread]
    attr_reader :thread

    # @!attribute [r]
    #
    # The read end of the pipe
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.pipe_reader #=> #<IO:fd 11>
    #
    # @return [IO]
    attr_reader :pipe_reader

    # @!attribute [r]
    #
    # The write end of the pipe
    #
    # @example
    #   pipe = ProcessExecuter::MonitoredPipe.new($stdout)
    #   pipe.pipe_writer #=> #<IO:fd 12>
    #
    # @return [IO] the write end of the pipe
    attr_reader :pipe_writer

    private

    # Reads data from the pipe forever until the monitoring thread is killed
    # @return [void]
    # @api private
    def monitor_pipe
      loop do
        read_pipe_output if pipe_reader.wait_readable
      end
    end

    # Read a chunk of data from the pipe and write it to the writers
    # @return [void]
    # @api private
    def read_pipe_output
      new_data = pipe_reader.read_nonblock(chunk_size)
      # puts "Received new data: #{new_data.inspect} from #{pipe_reader.inspect}"
      writers.each { |w| w.write(new_data) }
    rescue EOFError, IO::EAGAINWaitReadable
      # No output to read at this time
    end
  end
end
