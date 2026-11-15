# frozen_string_literal: true

# Another thread raises into the caller at a fixed interval while the caller makes leaking failures.
# usage: ruby interrupt.rb <std|exc> <iterations> <result-file> [interval-seconds]
#   std = the raised class is a StandardError; exc = it is an Exception
require_relative 'hooks'
kind = ARGV[0]
n = ARGV[1].to_i
out = ARGV[2]
interval = (ARGV[3] || '0.0005').to_f
$guard_restores = 0
ENV['PE_SKIP_CHDIR_CHECK'] = '1'
Interrupted = Class.new(kind == 'std' ? StandardError : Exception)
main = Thread.current
stop = false
raiser = Thread.new do
  until stop
    sleep interval
    main.raise(Interrupted, 'interrupted') unless stop
  end
end
outcomes = Hash.new(0)
first_leak = nil
done = 0
Thread.handle_interrupt(Interrupted => :never) do
  n.times do |i|
    begin
      Thread.handle_interrupt(Interrupted => :immediate) do
        ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir')
      end
      outcomes['returned'] += 1
    rescue Exception => e
      outcomes["#{e.class}: #{e.message[0, 50]}"] += 1
    end
    done = i + 1
    intact = begin
      STDOUT.syswrite('.')
      STDERR.syswrite('.')
      true
    rescue SystemCallError, IOError
      false
    end
    next if intact

    first_leak = i
    break
  end
  stop = true
  raiser.join
  File.write(out, format("%s kind=%s interval=#{interval} iterations=%d restores=%d streams left broken at iteration=%p | %p\n",
                         RUBY_VERSION, kind, done, $guard_restores, first_leak, outcomes))
end
