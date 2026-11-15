# frozen_string_literal: true

# One thread fails through the gem while a second thread calls Process.spawn directly, outside the gem's lock.
# usage: ruby raw_spawn.rb <noleak|leak> <result-file>
require_relative 'hooks'
mode, out = ARGV
$guard_restores = 0
ENV['PE_SKIP_CHDIR_CHECK'] = '1' if mode == 'leak'
limit = mode == 'leak' ? 400 : 1500
failing = mode == 'leak' ? -> { ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir') } : -> { ProcessExecuter.run_with_capture('no-such-program-for-hand-run') }
done = false
fail_outcomes = Hash.new(0)
raw_errors = Hash.new(0)
raw_ok = 0
slow = 0
failer = Thread.new do
  limit.times do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      failing.call
    rescue StandardError => e
      fail_outcomes["#{e.class.name}: #{e.message[0, 60]}"] += 1
    end
    slow += 1 if Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0 > 1
    Thread.pass
  end
  done = true
end
raw = Thread.new do
  until done
    begin
      # a child that lives about a second, so it overlaps many of the other thread's calls
      pid = Process.spawn('cmd', '/c', 'ping -n 2 127.0.0.1 >NUL')
      Process.wait(pid)
      raise "exit #{Process.last_status.exitstatus}" unless Process.last_status.success?

      raw_ok += 1
    rescue StandardError => e
      raw_errors["#{e.class.name}: #{e.message[0, 60]}"] += 1
    end
  end
end
[failer, raw].each(&:join)
mark = lambda do |io, text|
  io.syswrite(text)
  'ok'
rescue SystemCallError, IOError => e
  e.class.name
end
o = mark.call(STDOUT, "MARK-OUT\n")
e = mark.call(STDERR, "MARK-ERR\n")
File.write(out, format("%s raw-spawn thread, failing=%s: failures=%p restores=%d slow_calls=%d | raw spawns ok=%d errors=%p | afterwards out=%s err=%s\n",
                       RUBY_VERSION, mode, fail_outcomes, $guard_restores, slow, raw_ok, raw_errors, o, e))
