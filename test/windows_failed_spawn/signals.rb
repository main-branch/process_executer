# frozen_string_literal: true

# Signal-handler and Thread#kill unwinding through the guard.
# usage: ruby signals.rb <default_int|trap_raise|trap_throw|thread_kill> <leak|ok> <result-file>
#   leak = every call is a leaking failed spawn (chdir check off); ok = every call spawns successfully
require_relative 'hooks'
mode, kind, out = ARGV
ENV['PE_SKIP_CHDIR_CHECK'] = '1' if kind == 'leak'
$guard_restores = 0
class SigErr < StandardError
end
# Where the handler was each time it unwound a call, most recent last. Written beside the result
# when a call leaves a stream broken, to show which step the signal interrupted.
$unwound_at = []
note_unwind = lambda do
  $unwound_at << caller(2, 14)
  $unwound_at.shift while $unwound_at.size > 3
end
case mode
when 'trap_raise'
  trap('INT') do
    if $armed
      note_unwind.call
      raise SigErr, 'raised in trap handler'
    end
  end
when 'trap_throw'
  trap('INT') do
    if $armed
      note_unwind.call
      throw :sig, :thrown
    end
  end
end
call =
  if kind == 'leak'
    -> { ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir') }
  else
    -> { ProcessExecuter.run_with_capture('cmd /c echo hi') }
  end
intact = lambda do
  STDOUT.syswrite('.')
  STDERR.syswrite('.')
  true
rescue SystemCallError, IOError
  false
rescue Exception
  retry # a signal landed in the check itself
end
outcomes = Hash.new(0)
$armed = false
# A signal must unwind the call under test and nothing else in this script, so signals are let
# through only around the call. Ruby's default handler has no flag to test: it is swapped for
# IGNORE between calls.
arm, disarm =
  if mode == 'default_int'
    trap('INT', 'IGNORE')
    [-> { trap('INT', 'DEFAULT') }, -> { trap('INT', 'IGNORE') }]
  else
    [-> { $armed = true }, -> { $armed = false }]
  end
broken_at = nil
last_error = nil
done = 0
if mode == 'thread_kill'
  150.times do |i|
    worker = Thread.new do
      loop do
        call.call
      rescue ProcessExecuter::SpawnError
        nil
      end
    end
    worker.report_on_exception = false
    sleep(0.01 + (rand * 0.05))
    worker.kill
    begin
      worker.join
    rescue StandardError => e
      outcomes["killed thread ended with #{e.class}: #{e.message[0, 20]}"] += 1
    end
    done = i + 1
    next if intact.call

    broken_at = i
    break
  end
else
  stop = false
  signaler = Thread.new do
    until stop
      sleep 0.005
      Process.kill('INT', Process.pid) unless stop
    end
  end
  300.times do |i|
    e = nil
    result = nil
    called = false
    begin
      unless called
        begin
          e = nil
          arm.call
          result = catch(:sig) do
            call.call
            :returned
          end
        rescue Exception => e
          nil # recorded below
        ensure
          called = true
        end
      end
      disarm.call
    rescue Exception
      retry # a signal landed after the call and before the disarm; finish disarming
    end
    outcomes[e ? "#{e.class}: #{e.message[0, 45]}" : result.to_s] += 1
    last_error = e
    done = i + 1
    next if intact.call

    broken_at = i
    break
  end
  stop = true
  signaler.join
end
if broken_at
  # The error the breaking call ended with, then where the handler last unwound a call
  trace = last_error&.backtrace || []
  trace = trace.first(25) + ['...'] + trace.last(25) if trace.size > 50
  report = ["#{last_error.class}: #{last_error&.message}", *trace, '', '-- handler unwound the call at:']
  report += $unwound_at.map { |frames| "#{frames.join("\n")}\n" }
  File.write("#{out}.unwound.txt", report.join("\n"))
end
File.write(out, format("%s %-11s %-4s calls=%d restores=%d streams left broken at call=%p | %p\n",
                       RUBY_VERSION, mode, kind, done, $guard_restores, broken_at, outcomes))
