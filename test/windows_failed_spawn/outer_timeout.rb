# frozen_string_literal: true

# An outer Timeout.timeout that expires during the wait or during the spawn, and a coercion
# method that itself runs a command through the gem.
# usage: ruby outer_timeout.rb <outer_timeout_during_wait|outer_timeout_during_spawn|reentry> <result-file>
require_relative 'hooks'
require 'stringio'
require 'timeout'
kase, out = ARGV
# PIDs of the ping.exe processes this script started. The gem starts ping as a direct child of
# this process, so the parent process id picks out ours and no other ping on the machine.
query = %(Get-CimInstance Win32_Process -Filter "Name='PING.EXE' AND ParentProcessId=#{Process.pid}" | ForEach-Object { $_.ProcessId })
ping_pids = -> { IO.popen(['powershell', '-NoProfile', '-Command', query], &:read).scan(/\d+/).map(&:to_i) }
outcome = begin
  case kase
  when 'outer_timeout_during_wait'
    Timeout.timeout(1) { ProcessExecuter.run('ping -n 20 127.0.0.1', out: StringIO.new, err: StringIO.new, timeout_after: 60) }
  when 'outer_timeout_during_spawn'
    value = Object.new
    def value.to_str
      sleep(1.5) # the outer timeout expires in here, inside Process.spawn
      'x'
    end
    Timeout.timeout(0.5) { ProcessExecuter.run({ 'V' => value }, 'ping -n 20 127.0.0.1', out: StringIO.new, err: StringIO.new, timeout_after: 60) }
  when 'reentry'
    value = Object.new
    def value.to_str = ProcessExecuter.run_with_capture('cmd /c echo inner').stdout.strip
    ProcessExecuter.run_with_capture({ 'V' => value }, 'cmd /c echo %V%').stdout.strip.inspect
  end
rescue Exception => e
  "#{e.class}: #{e.message[0, 90]}"
end
sleep 0.5
left_pids = ping_pids.call
left = left_pids.size
File.write(out, format("%s timeout-gem=%s %-26s | ping.exe left running=%d | %s\n", RUBY_VERSION, Timeout::VERSION, kase, left, outcome))
left_pids.each { |pid| system("taskkill /F /PID #{pid} >NUL 2>&1") }
