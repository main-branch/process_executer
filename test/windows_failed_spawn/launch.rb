# frozen_string_literal: true

# Runs a script in its own process group so console control events it generates reach nothing else.
# usage: ruby launch.rb <stdout-file> <stderr-file> <command...>
out, err, *command = ARGV
pid = Process.spawn(*command, out: out, err: err, new_pgroup: true)
finished = false
killer = Thread.new do
  sleep 180
  Process.kill('KILL', pid) unless finished
end
Process.wait(pid)
finished = true
killer.kill
