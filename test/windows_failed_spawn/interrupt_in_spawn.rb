# frozen_string_literal: true

# Another thread raises into the caller during a spawn that succeeds, at a known point: an env
# value's #to_str, which Process.spawn calls while it builds the child's environment.
# usage: ruby interrupt_in_spawn.rb <result-file>
require_relative 'hooks'
require 'stringio'
require 'tmpdir'
out = ARGV.fetch(0)
class Interrupted < StandardError
end
calls = 0
value = Object.new
value.define_singleton_method(:to_str) do
  calls += 1
  caller_thread = Thread.current
  Thread.new { caller_thread.raise(Interrupted, 'interrupted') }.join if calls == 1
  'x'
end
marker = File.join(Dir.mktmpdir, 'ran.txt')
outcome = begin
  ProcessExecuter.run({ 'HAND_RUN_VALUE' => value }, "cmd /c echo ran> \"#{marker.tr('/', '\\')}\"", out: StringIO.new, err: StringIO.new)
  'returned'
rescue Exception => e
  "#{e.class}: #{e.message}"
end
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
sleep 0.05 until File.exist?(marker) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
File.write(out, format("%s to_str calls=%d | command ran=%s | %s\n", RUBY_VERSION, calls, File.exist?(marker), outcome))
