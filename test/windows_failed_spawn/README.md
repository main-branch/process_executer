# Windows failed-spawn hand-runs

Scripts that check, on Windows MRI, what a failed `Process.spawn` leaves behind in the
calling process when the call goes through this gem. They were written for
[issue 204](https://github.com/main-branch/process_executer/issues/204) and
[issue 211](https://github.com/main-branch/process_executer/issues/211) and are kept
for any later change to the code those issues added:

- `SpawnWithTimeout#check_chdir`, which keeps a bad `chdir:` directory from reaching
  `Process.spawn`
- `StandardStreamGuard`, which points stdout and stderr back after a failed spawn
  that the check could not prevent

Run them before merging a change to either, to `Run`'s pipe handling, or to
`MonitoredPipe#close`. They are not part of `rake` or of CI: they need Windows, they
take about 30 minutes for four Rubies, and several of them are races that only show
a problem some of the time.

Nothing in this directory is packaged in the gem.

## Why the suite is not enough

The examples in `spec/` run on Windows in CI and cover each of these cases once. The
scripts here do what an example can't:

- repeat a race hundreds of times, with another thread interrupting, writing, or
  spawning at the same time
- run a process out of file descriptors
- send the process real Ctrl-C events
- load every core so that a rare freeze becomes likely

## Running

The two driver scripts need PowerShell 7 (`pwsh`). From this directory:

```powershell
pwsh -File run.ps1 -Ruby C:\path\to\ruby.exe
```

`-Ruby` takes a comma-separated list of `ruby.exe` paths and runs everything once
per Ruby. It defaults to the `ruby` on the `PATH`. The gem is loaded from this
checkout's `lib`, not from an installed gem.

Each Ruby needs the gem's runtime dependency, `track_open_instances`, installed.
For a Ruby that doesn't have it, pass a directory that holds a copy:

```powershell
pwsh -File run.ps1 -Ruby C:\rubies\3.4.10\bin\ruby.exe,C:\rubies\4.0.6\bin\ruby.exe -LoadPath C:\path\to\track_open_instances\lib
```

`-SignalsOnly` runs only the signal stress, which takes about 8 minutes for four
Rubies.

Results go to `results\run.log`, one line per run, ending with a `DONE` line. Over
ssh, start the script detached and poll the log: Windows sshd stops everything a
session started when the session closes.

The scripts fail on purpose in a way the gem's `chdir:` check would stop, so
`hooks.rb` turns the check off when a script asks for it. It also counts how many
times the guard restored the streams, which the log reports as `restores=`.

## What to look for

A healthy log has none of these:

| In the log | Meaning |
|---|---|
| `NO RESULT` | The script ended without writing its result. The line carries the last two lines of its stderr. |
| `[process did not exit; stopped after timeout]` | The script hung. For `threads.rb writer leak` this is the freeze in [issue 210](https://github.com/main-branch/process_executer/issues/210). |
| `streams left broken at iteration=` or `at call=` followed by a number | A call returned with stdout or stderr still pointed at a pipe. `nil` is the healthy value. |
| `out=` or `err=` followed by an error class | A write to the stream after the call raised. `ok` is the healthy value. |
| `reached files out/err/child=` with a `False` | A marker written after the call did not reach the file the script's stream was redirected to. |
| `slow_calls=` above 0 | A call took more than a second, which is what a pipe waiting out its close timeout looks like. |

The counts in the randomised sections change from run to run. Compare outcomes, not
numbers.

## Sections of the log

### `cases`

`cases.rb` makes one call per process and then checks the process: a marker written
to stdout and to stderr, a child process's output, and a later `run_with_capture`.

| Case | The call | Expected |
|---|---|---|
| `capture_missing_dir_nocheck` | `run_with_capture`, missing `chdir:`, check off | `SpawnError`, cause `Errno::ENOENT`, `restores=1` |
| `run_stringio_missing_dir_nocheck` | `run` to `StringIO`s, missing `chdir:`, check off | the same |
| `run_file_missing_dir_nocheck` | `run` with `out:` a file path, missing `chdir:`, check off | the same |
| `run_noredirect_missing_dir_nocheck` | `run` with no redirection, missing `chdir:`, check off | `SpawnError`, `restores=0`: no pipe was attached, so there is nothing to repair |
| `capture_env_missing_dir_nocheck` | as the first, with an env variable passed | `restores=1`, and `ENV[HAND_RUN_LEAK]="1"`: the env still leaks ([issue 205](https://github.com/main-branch/process_executer/issues/205)) |
| `capture_denied_dir` | `chdir:` is a directory the user may not enter | `SpawnError`, cause `Errno::EACCES`, `restores=1` |
| `run_stringio_denied_dir` | the same through `run` | the same |
| `capture_missing_dir_other_thread_chdir` | missing `chdir:` while another thread is inside a `Dir.chdir` block | `SpawnError`, cause `Errno::ENOENT`, `restores=1` |
| `capture_missing_dir` | missing `chdir:`, check on | `SpawnError`, cause `Errno::ENOENT`, `restores=0`: the check stopped it |
| `capture_file_as_dir` | `chdir:` is a file, check on | `SpawnError`, cause `Errno::EINVAL`, `restores=0` |
| `capture_missing_program` | the program does not exist | `SpawnError`, cause `Errno::ENOENT`, `restores=0`: this failure leaks nothing |
| `capture_success` | a command that works | `returned "hi\r\n"` |
| `capture_bad_dir_out_file` | missing `chdir:`, check on, `out:` a file path | `SpawnError`, and `out_file_created=true`, as `Process.spawn` would leave it |

Every case should take well under a second and end with
`reached files out/err/child=True/True/True`.

### `interrupt`

`interrupt.rb` makes 400 leaking failures while another thread raises into the
caller at a fixed interval (0.5 ms, 5 ms, 20 ms), once with a `StandardError` and
once with an `Exception`. Expected: `streams left broken at iteration=nil` on every
line. The mix of `SpawnError` and `Interrupted` outcomes varies.

### `threads`

`threads.rb` runs a failing thread beside a second thread.

| Second thread | Failures | Expected |
|---|---|---|
| `writer`: writes lines to stderr | `noleak` (3,000 missing programs) | `restores=0`, no errors in the second thread |
| `writer` | `leak` (600 leaking failures) | `restores=600`. The writer gets `Errno::EPIPE`, and on Ruby 3.1 to 3.4 also `IOError: stream closed in another thread`, about once per repair. That is documented in `StandardStreamGuard`. |
| `spawner`: makes successful `run_with_capture` calls | `noleak` | `restores=0`, no errors |
| `spawner` | `leak` | `restores=600`, no errors: no capture got another call's output |

Every line should end `afterwards out=ok err=ok`.

### `raw spawn`

`raw_spawn.rb` fails through the gem while a second thread calls `Process.spawn`
directly, outside the guard's lock. Expected: `slow_calls=0`, no errors in the raw
spawns, `afterwards out=ok err=ok`.

### `exhaust`

`exhaust.rb` makes leaking failures until the process is out of descriptors. Ruby
never closes the two descriptor copies it makes for each such failure, and nothing
in Ruby code can. Expected: about 4,090 failures with `out=ok err=ok`, then
`SpawnError: ... Too many open files` with `out=ok err=ok` still, and
`slow_calls=0`.

### `interrupt during a successful spawn`

`interrupt_in_spawn.rb` has another thread raise into the caller at a known point
inside a spawn that succeeds. Expected: `command ran=true` and the outcome
`Interrupted: interrupted`, not a `SpawnError`.

`interrupt_successful_spawns.rb` does the same at random points over 300 calls.
Expected: only `returned` and `Interrupted` outcomes. `children never waited for`
is a small number, not 0: `run` without `timeout_after:` does not kill a subprocess
it did not isolate.

### `outer timeout and re-entry`

`outer_timeout.rb` has three cases.

| Case | Expected |
|---|---|
| `outer_timeout_during_wait` | Ruby 3.3 and later: `Timeout::Error`, `ping.exe left running=0`. Ruby 3.1 and 3.2: `ping.exe left running=1` and a `ProcessIOError`, which is [issue 209](https://github.com/main-branch/process_executer/issues/209). |
| `outer_timeout_during_spawn` | `Timeout::Error`, `ping.exe left running=0` |
| `reentry` | `"inner\""`: an env value's `#to_str` ran a command through the gem from inside the guard's lock |

The script counts and stops only `ping.exe` processes that are its own children, by
process id.

### `signal stress`

`signals.rb` sends its own process a Ctrl-C event every 5 ms, or kills the calling
thread at a random moment, over 300 calls (150 for `thread_kill`). `launch.rb`
starts it in a process group of its own so the events reach nothing else.

| Mode | What unwinds the call |
|---|---|
| `default_int` | Ruby's default handler raises `Interrupt` |
| `trap_raise` | a `trap` handler raises |
| `trap_throw` | a `trap` handler throws |
| `thread_kill` | `Thread#kill` from another thread |

Each mode runs with leaking failures and again with successful spawns. Expected:
`streams left broken at call=nil` on every line.

The script lets a signal through only around the call under test, so a signal can't
unwind the script's own bookkeeping. When a call does leave a stream broken, the
script also writes `sig.txt.unwound.txt` in the results directory: the error that
call ended with, its backtrace, and where the handler was the last three times it
unwound a call.

Three failures were found in 4.1.2, and the first is fixed in the release after it.
All need a handler that raises while a call
is in progress, and all are rare: with a signal every 5 ms, each showed up a few
times in several thousand runs of the two `trap` modes with leaking failures.

- **The call ends with `SystemStackError: stack level too deep`, sometimes with a
  stream left broken.** If a handler raises inside `MonitoredPipe#close` after the
  pipe's state is set to closing and before its monitoring thread is woken, the
  thread is never woken, and the guard's restart of the repair waits for it. With
  one signal that is a hang. Under this script's stream of signals each one
  restarts the repair one level deeper until the stack runs out, after about 30
  seconds. Fixed: [issue 218](https://github.com/main-branch/process_executer/issues/218).
- **The same error, once, with issue 218 fixed.** Seen in one run in about 3,700.
  The cause is not known.
  [Issue 222](https://github.com/main-branch/process_executer/issues/222).
- **The call ends with `SpawnError: ... Bad file descriptor @ io_reopen - <STDOUT>`
  and stdout is left broken.** A bug in Ruby: an exception raised into `IO.pipe`
  leaves a descriptor number that Ruby closes twice, the second time at a later
  garbage collection, when the number may belong to the guard's copy of stdout.
  [Issue 220](https://github.com/main-branch/process_executer/issues/220). The
  handler has to raise while a call is creating its pipes, which shows in the
  result line as one outcome of a bare `SigErr`, not wrapped in `SpawnError`.

`hooks.rb` writes `restore-error-<pid>.txt` in the results directory when a restore
raises: the error, how deep the restart was, and the state of each copy and stream.

## The freeze loop

`freeze_loop.ps1` repeats the run that exposed
[issue 210](https://github.com/main-branch/process_executer/issues/210): 600
leaking failures beside a thread writing to stderr. That issue is a bug in Ruby in
which the whole process stops; `StandardStreamGuard` avoids the two operations that
trigger it. The freeze is a race and shows up far more often when every core is
busy.

```powershell
pwsh -File freeze_loop.ps1 -Ruby C:\path\to\ruby.exe -Runs 400 -Burners 16 -Tag 4.0.6
```

- `-Burners` starts that many busy-loop processes (`burn.rb`), one per core is the
  useful number. They exit after `-BurnMinutes` (60 by default), and the script
  stops the ones it started when it ends.
- A run that has not exited after 60 seconds is logged as `FROZEN` and stopped.
  The script ends after `-Want` frozen runs (3 by default).
- `-Gdb C:\path\to\gdb.exe` saves a backtrace of every thread of each frozen run.

The log is `results\freeze-<Tag>.log` and ends with
`DONE ... frozen=<count> healthy=<count> of <runs>`. Expected: `frozen=0` and every
run healthy. The loop stops early, with a `NO RESULT` or `UNHEALTHY` line, at the
first run that exits without a result or with a stream that doesn't work: such a run
says nothing about freezing.

Before the guard avoided those operations, a 16-core machine froze about once in 15
to 170 runs, depending on load; with them avoided, 1,600 runs under 16 burners did
not freeze. 400 runs take about 50 minutes under that load, and two Rubies can run
side by side with different `-Tag` values.

Run it on Ruby 3.4 and on 4.0 after any change to how `StandardStreamGuard` or
`MonitoredPipe` closes, reopens, or copies a descriptor. No example in the suite
can stand in for it.
