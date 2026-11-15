# frozen_string_literal: true

# One failed (or successful) call per process, then a check that stdout and stderr still work.
# usage: ruby cases.rb <case> <result-file> [denied-dir]
# The caller redirects this script's stdout and stderr to files and looks for the markers in them.
require_relative 'hooks'
require 'stringio'
kase, out, denied = ARGV
$guard_restores = 0
precheck_off = -> { ENV['PE_SKIP_CHDIR_CHECK'] = '1' }
call =
  case kase
  when 'capture_missing_dir_nocheck'
    precheck_off.call
    -> { ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir') }
  when 'run_stringio_missing_dir_nocheck'
    precheck_off.call
    -> { ProcessExecuter.run('cmd /c echo hi', chdir: 'no-such-dir', out: StringIO.new, err: StringIO.new) }
  when 'run_file_missing_dir_nocheck'
    precheck_off.call
    -> { ProcessExecuter.run('cmd /c echo hi', chdir: 'no-such-dir', out: "case-out-#{Process.pid}.txt") }
  when 'run_noredirect_missing_dir_nocheck'
    precheck_off.call
    -> { ProcessExecuter.run('cmd /c echo hi', chdir: 'no-such-dir') }
  when 'capture_env_missing_dir_nocheck'
    precheck_off.call
    -> { ProcessExecuter.run_with_capture({ 'HAND_RUN_LEAK' => '1' }, 'cmd /c echo hi', chdir: 'no-such-dir') }
  when 'capture_denied_dir' then -> { ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: denied) }
  when 'run_stringio_denied_dir' then -> { ProcessExecuter.run('cmd /c echo hi', chdir: denied, out: StringIO.new, err: StringIO.new) }
  when 'capture_missing_dir_other_thread_chdir'
    lambda do
      entered = Queue.new
      release = Queue.new
      blocker = Thread.new do
        Dir.chdir(Dir.pwd) do
          entered << 1
          release.pop
        end
      end
      entered.pop
      begin
        ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir')
      ensure
        release << 1
        blocker.join
      end
    end
  when 'capture_missing_dir' then -> { ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir') }
  when 'capture_file_as_dir' then -> { ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: __FILE__) }
  when 'capture_missing_program' then -> { ProcessExecuter.run_with_capture('no-such-program-for-hand-run') }
  when 'capture_success' then -> { ProcessExecuter.run_with_capture('cmd /c echo hi').stdout.inspect }
  when 'capture_bad_dir_out_file'
    # Does a file redirection get created when the directory is bad?
    -> { ProcessExecuter.run('cmd /c echo hi', chdir: 'no-such-dir', out: "created-#{Process.pid}.txt") }
  end

t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
outcome = begin
  v = call.call
  "returned #{v.is_a?(String) ? v : v.class}"
rescue StandardError => e
  "#{e.class}: #{e.message} (cause #{e.cause.class})"
end
secs = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
mark = lambda do |io, text|
  io.syswrite(text)
  'ok'
rescue SystemCallError, IOError => e
  e.class.name
end
out_mark = mark.call(STDOUT, "MARK-OUT-#{kase}\n")
err_mark = mark.call(STDERR, "MARK-ERR-#{kase}\n")
system('cmd', '/c', "echo CHILD-MARK-#{kase}")
again = begin
  ProcessExecuter.run_with_capture('cmd /c echo again').stdout.strip
rescue StandardError => e
  e.class.name
end
extra = kase == 'capture_bad_dir_out_file' ? " out_file_created=#{File.exist?("created-#{Process.pid}.txt")}" : ''
extra += " ENV[HAND_RUN_LEAK]=#{ENV['HAND_RUN_LEAK'].inspect}" if kase.include?('env')
File.write(out, format("%-40s %.2fs restores=%d out=%s err=%s later_capture=%s%s | %s\n", kase, secs, $guard_restores, out_mark, err_mark, again, extra, outcome))
