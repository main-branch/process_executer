# frozen_string_literal: true

require 'json'
require 'tmpdir'

# StandardStreamGuard is used only on Windows MRI, where a failed spawn can
# leave fd 1 and fd 2 pointed at the spawn's redirection targets. Its own
# logic runs on any MRI, so these examples make the leak themselves: the block
# given to #call reopens a standard stream onto a pipe and then raises, as a
# leaking Process.spawn would.
#
# Each example runs in a child Ruby process that writes what it found to a
# file, because the leak redirects the standard streams of the process it
# happens in.
#
RSpec.describe ProcessExecuter::Commands::StandardStreamGuard, if: mri? do
  describe '#call' do
    subject(:findings) do
      ProcessExecuter.spawn_with_timeout(
        RbConfig.ruby, '-I', File.expand_path('../../../lib', __dir__), script_path, scenario, tmpdir,
        out: stdout_path, err: stderr_path, timeout_after: 120
      )
      JSON.parse(File.read(File.join(tmpdir, 'findings.json'))).merge(
        'stdout' => File.read(stdout_path), 'stderr' => File.read(stderr_path)
      )
    end

    let(:tmpdir) { File.realpath(Dir.mktmpdir) }
    let(:stdout_path) { File.join(tmpdir, 'stdout.txt') }
    let(:stderr_path) { File.join(tmpdir, 'stderr.txt') }
    let(:script_path) { File.join(tmpdir, 'guard.rb').tap { |path| File.write(path, script) } }

    let(:script) { <<~'SCRIPT' }
      require 'json'
      require 'process_executer'

      scenario, dir = ARGV
      findings = {}

      class HandlerError < StandardError; end

      # A pipe whose first close has a signal delivered to this process and
      # returns once the handler has started. It stands in for a signal that
      # arrives while the guard is checking for a leak.
      handler_started = Queue.new
      signalled = false
      signalling = Object.new
      signalling.define_singleton_method(:close) do |timeout:|
        next if signalled

        signalled = true
        Process.kill('INT', Process.pid)
        handler_started.pop
      end
      def signalling.truncated? = false
      def signalling.destination_failed? = false
      def signalling.pipe_writer = @pipe_writer ||= File.open(File::NULL, 'wb')

      pipes =
        case scenario
        when 'leak'
          { out: ProcessExecuter::MonitoredPipe.new(StringIO.new) }
        when 'leak_and_another_pipe_fails_to_close'
          unclosable = Object.new
          def unclosable.close(timeout:) = raise(IOError, 'close failed')
          def unclosable.truncated? = false
          def unclosable.destination_failed? = false
          def unclosable.pipe_writer = @pipe_writer ||= File.open(File::NULL, 'wb')
          { err: unclosable, out: ProcessExecuter::MonitoredPipe.new(StringIO.new) }
        when 'leak_and_destination_write_fails', 'leak_and_destination_write_raises_eof'
          # EOFError is also what the pipe's reading thread records when the
          # guard takes the write end away and nothing leaked
          write_error = scenario.end_with?('eof') ? EOFError : IOError
          unwritable = Object.new
          unwritable.define_singleton_method(:write) { |_data| raise(write_error, 'write failed') }
          { out: ProcessExecuter::MonitoredPipe.new(unwritable) }
        when 'leak_and_signal_handler_raises_during_check'
          trap('INT') { handler_started << true and raise(HandlerError, 'raised by the handler') }
          { err: signalling, out: ProcessExecuter::MonitoredPipe.new(StringIO.new) }
        when 'leak_and_signal_handler_throws_during_check'
          trap('INT') { handler_started << true and throw(:handler_threw) }
          { err: signalling, out: ProcessExecuter::MonitoredPipe.new(StringIO.new) }
        when 'leak_and_block_throws', 'no_leak', 'reentry'
          { out: ProcessExecuter::MonitoredPipe.new(StringIO.new) }
        end

      guard = ProcessExecuter::Commands::StandardStreamGuard.new(pipes)
      begin
        findings['thrown'] = catch(:handler_threw) { catch(:block_threw) { guard.call do
          if scenario == 'reentry'
            # What a coercion method that itself runs a command would do
            inner = ProcessExecuter::Commands::StandardStreamGuard.new({})
            findings['inner'] = inner.call { 'inner ran' }
          end
          unless %w[no_leak reentry].include?(scenario)
            STDOUT.reopen(pipes[:out].to_io)
            if scenario.start_with?('leak_and_destination_write')
              # What another thread writing to the leaked stdout would do
              STDOUT.syswrite('written into the leaked pipe')
              Thread.pass until pipes[:out].exception
            end
          end
          throw(:block_threw, 'by the block') if scenario == 'leak_and_block_throws'
          raise Errno::EACCES, 'spawn failed'
        end } }
      rescue StandardError => e
        findings['error'] = e.class.name
      end
      findings['pipes_closed'] = guard.pipes_closed?

      { STDOUT => "MARK-OUT\n", STDERR => "MARK-ERR\n" }.each do |io, marker|
        io.syswrite(marker)
      rescue SystemCallError, IOError
        nil # the parent sees that the marker is missing from the file
      end

      File.write(File.join(dir, 'findings.json'), JSON.generate(findings))
    SCRIPT

    # The block's error reached the caller, the pipes are closed, and a write
    # to fd 1 and to fd 2 afterward reached the file the child was started with
    let(:streams_intact) do
      {
        'error' => 'Errno::EACCES',
        'pipes_closed' => true,
        'stdout' => include('MARK-OUT'),
        'stderr' => include('MARK-ERR')
      }
    end

    after { FileUtils.remove_entry(tmpdir) }

    context 'when the block raises and leaves stdout pointed at a pipe' do
      let(:scenario) { 'leak' }

      it 'points stdout back and raises the error from the block' do
        expect(findings).to include(streams_intact)
      end
    end

    context 'when the block raises, leaks stdout, and another pipe fails to close' do
      let(:scenario) { 'leak_and_another_pipe_fails_to_close' }

      it 'still points stdout back and raises the error from the block' do
        expect(findings).to include(streams_intact)
      end
    end

    context 'when the block raises, leaks stdout, and the destination failed on data written to the leak' do
      let(:scenario) { 'leak_and_destination_write_fails' }

      it 'still points stdout back and raises the error from the block' do
        expect(findings).to include(streams_intact)
      end
    end

    context 'when the block raises, leaks stdout, and the destination raised EOFError on data written to the leak' do
      let(:scenario) { 'leak_and_destination_write_raises_eof' }

      it 'still points stdout back and raises the error from the block' do
        expect(findings).to include(streams_intact)
      end
    end

    context 'when the block throws and leaves stdout pointed at a pipe' do
      let(:scenario) { 'leak_and_block_throws' }

      it 'points stdout back and lets the throw through' do
        expect(findings).to include(
          'thrown' => 'by the block', 'pipes_closed' => true,
          'stdout' => include('MARK-OUT'), 'stderr' => include('MARK-ERR')
        )
      end
    end

    context 'when a signal handler raises while a leak is being checked for' do
      let(:scenario) { 'leak_and_signal_handler_raises_during_check' }

      it 'still points stdout back and raises the error from the handler' do
        expect(findings).to include(streams_intact.merge('error' => 'HandlerError'))
      end
    end

    context 'when a signal handler throws while a leak is being checked for' do
      let(:scenario) { 'leak_and_signal_handler_throws_during_check' }

      it 'still points stdout back and lets the throw through' do
        expect(findings).to include(
          'pipes_closed' => true, 'stdout' => include('MARK-OUT'), 'stderr' => include('MARK-ERR')
        )
        expect(findings).not_to include('error')
      end
    end

    context 'when the block calls another guard on the same thread' do
      let(:scenario) { 'reentry' }

      it 'runs the inner block' do
        expect(findings).to include(streams_intact.merge('inner' => 'inner ran'))
      end
    end

    context 'when the block raises without leaking' do
      let(:scenario) { 'no_leak' }

      it 'raises the error from the block and leaves stdout and stderr working' do
        expect(findings).to include(streams_intact)
      end
    end
  end
end
