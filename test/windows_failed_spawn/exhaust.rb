# frozen_string_literal: true

# Leaking failures until the process runs out of descriptors. usage: ruby exhaust.rb <result-file>
require_relative 'hooks'
$guard_restores = 0
ENV['PE_SKIP_CHDIR_CHECK'] = '1'
# Opened first and kept open: once the process is out of descriptors a later open would fail
res = File.open(ARGV[0], 'w') # rubocop:disable Style/FileOpen
res.sync = true
mark = lambda do |io|
  io.syswrite('.')
  'ok'
rescue SystemCallError, IOError => e
  e.class.name
end
last = nil
after_change = 0
slow = 0
6000.times do |i|
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  outcome = begin
    ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir')
    'returned'
  rescue Exception => e
    "#{e.class}: #{e.message[0, 70]}"
  end
  secs = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  slow += 1 if secs > 1
  o = mark.call(STDOUT)
  er = mark.call(STDERR)
  state = "#{outcome} | out=#{o} err=#{er}"
  if state != last
    res.puts format('%s iteration=%d restores=%d %.2fs %s', RUBY_VERSION, i, $guard_restores, secs, state)
    last = state
  end
  after_change += 1 if outcome !~ /No such file or directory - no-such-dir/ || o != 'ok' || er != 'ok'
  if after_change >= 6 || slow >= 3
    res.puts format('%s stopped at iteration=%d restores=%d slow_calls=%d', RUBY_VERSION, i, $guard_restores, slow)
    break
  end
end
res.puts format('%s end restores=%d slow_calls=%d', RUBY_VERSION, $guard_restores, slow)
