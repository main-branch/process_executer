# frozen_string_literal: true

# One thread makes failing calls while a second thread uses stdout, stderr, or the gem.
# usage: ruby threads.rb <writer|spawner> <noleak|leak> <result-file>
#   second thread: writer = writes lines to STDERR; spawner = makes successful run_with_capture calls
#   failing thread: noleak = missing program; leak = missing chdir with the pre-check off
require_relative 'hooks'
other, mode, out = ARGV
$guard_restores = 0
ENV['PE_SKIP_CHDIR_CHECK'] = '1' if mode == 'leak'
limit = mode == 'leak' ? 600 : 3000 # each leaking failure costs descriptors Ruby never closes
failing = mode == 'leak' ? -> { ProcessExecuter.run_with_capture('cmd /c echo hi', chdir: 'no-such-dir') } : -> { ProcessExecuter.run_with_capture('no-such-program-for-hand-run') }
done = false
fail_errors = Hash.new(0)
other_errors = Hash.new(0)
other_ok = 0
failer = Thread.new do
  limit.times do
    begin
      failing.call
    rescue StandardError => e
      fail_errors["#{e.class.name}: #{e.message[0, 60]}"] += 1
    end
    Thread.pass
  end
  done = true
end
second = Thread.new do
  line = "#{'log line ' * 20}\n"
  until done
    begin
      if other == 'writer'
        STDERR.write(line)
      else
        got = ProcessExecuter.run_with_capture('cmd /c echo hi').stdout
        raise "wrong capture #{got.inspect}" unless got.strip == 'hi'
      end
      other_ok += 1
    rescue StandardError => e
      other_errors["#{e.class.name}: #{e.message[0, 60]}"] += 1
    end
  end
end
[failer, second].each(&:join)
mark = lambda do |io, text|
  io.syswrite(text)
  'ok'
rescue SystemCallError, IOError => e
  e.class.name
end
o = mark.call(STDOUT, "MARK-OUT\n")
e = mark.call(STDERR, "MARK-ERR\n")
File.write(out, format("%s second=%s failing=%s: failures=%p restores=%d | second thread ok=%d errors=%p | afterwards out=%s err=%s\n",
                       RUBY_VERSION, other, mode, fail_errors.values.sum, $guard_restores, other_ok, other_errors, o, e))
