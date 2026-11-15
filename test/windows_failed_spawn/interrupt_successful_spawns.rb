# frozen_string_literal: true

# Another thread raises into the caller at a fixed interval while the caller makes calls that succeed.
# usage: ruby interrupt_successful_spawns.rb <interval-seconds> <result-file>
require_relative 'hooks'
require 'stringio'
interval = ARGV[0].to_f
out = ARGV[1]
class Interrupted < StandardError
end
main = Thread.current
stop = false
raiser = Thread.new do
  until stop
    sleep interval
    main.raise(Interrupted, 'interrupted') unless stop
  end
end
outcomes = Hash.new(0)
Thread.handle_interrupt(Interrupted => :never) do
  300.times do
    Thread.handle_interrupt(Interrupted => :immediate) do
      ProcessExecuter.run('cmd /c exit 0', out: StringIO.new, err: StringIO.new)
    end
    outcomes['returned'] += 1
  rescue Exception => e
    outcomes["#{e.class}: #{e.message[0, 50]}"] += 1
  end
  stop = true
  raiser.join
  unreaped = begin
    Process.waitall.size
  rescue StandardError => e
    e.class.name
  end
  # Written before the mask is lifted: a raise still queued is delivered when this block ends
  File.write(out, format("%s interval=%s | children never waited for=%p | %p\n", RUBY_VERSION, interval, unreaped, outcomes))
end
