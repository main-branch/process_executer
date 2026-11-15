# Runs the hand-run scripts in this directory against the gem in this checkout, once per Ruby,
# and writes one line per run to <OutDir>\run.log. The log ends with a DONE line.
#
#   pwsh -File run.ps1 -Ruby C:\path\to\ruby.exe[,C:\path\to\another\ruby.exe]
#
# See README.md for what each section shows and what a failure looks like.
param(
  # One ruby.exe per Ruby to test. Defaults to the ruby on the PATH.
  [string[]]$Ruby = @((Get-Command ruby).Source),
  # Extra load paths, for a Ruby that doesn't have the gem's runtime dependencies installed
  [string[]]$LoadPath = @(),
  [string]$OutDir = (Join-Path $PSScriptRoot 'results'),
  # Run only the signal stress, the last and slowest-to-diagnose part
  [switch]$SignalsOnly
)

# `pwsh -File` passes a,b as one string, so split the lists here
$Ruby = @($Ruby | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$LoadPath = @($LoadPath | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$missing = @($Ruby + $LoadPath | Where-Object { -not (Test-Path $_) })
if ($missing) { throw "No such path: $($missing -join ', ')" }
# Made absolute before the location changes, so a relative argument still points at the same place
$Ruby = @($Ruby | ForEach-Object { (Resolve-Path $_).Path })
$LoadPath = @($LoadPath | ForEach-Object { (Resolve-Path $_).Path })
$OutDir = (New-Item -ItemType Directory $OutDir -Force).FullName

$lib = Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'lib'
Set-Location $OutDir
$log = Join-Path $OutDir 'run.log'
Remove-Item $log -Force -ErrorAction SilentlyContinue
function Log($s) { $s | Out-File -FilePath $log -Append -Encoding utf8 }
$include = (@($lib) + $LoadPath | ForEach-Object { "-I `"$_`"" }) -join ' '
function Script($name) { "`"$(Join-Path $PSScriptRoot $name)`"" }

# Run one script to completion, or stop it after the timeout, and log the line(s) it wrote
function RunRuby($ruby, $name, $scriptArgs, $resultFile, $timeoutSec) {
  Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
  $p = Start-Process -FilePath $ruby -ArgumentList "$include $(Script $name) $scriptArgs" -NoNewWindow -PassThru `
    -RedirectStandardOutput 'stdout.txt' -RedirectStandardError 'stderr.txt'
  $hung = -not $p.WaitForExit($timeoutSec * 1000)
  if ($hung) { Stop-Process -Id $p.Id -Force }
  $note = if ($hung) { ' [process did not exit; stopped after timeout]' } else { '' }
  if (Test-Path $resultFile) {
    Get-Content $resultFile | ForEach-Object { Log "$_$note" }
  } else {
    Log "NO RESULT $name $scriptArgs$note :: $((Get-Content stderr.txt -Tail 2) -join ' / ')"
  }
}

$cases = 'capture_missing_dir_nocheck', 'run_stringio_missing_dir_nocheck', 'run_file_missing_dir_nocheck',
  'run_noredirect_missing_dir_nocheck', 'capture_env_missing_dir_nocheck', 'capture_denied_dir',
  'run_stringio_denied_dir', 'capture_missing_dir_other_thread_chdir', 'capture_missing_dir',
  'capture_file_as_dir', 'capture_missing_program', 'capture_success', 'capture_bad_dir_out_file'

Log "START $(Get-Date -Format s)"
foreach ($r in $Ruby) {
  if ($SignalsOnly) { break }
  $v = & $r -e 'print RUBY_VERSION'
  Log "== cases $v $(Get-Date -Format s)"
  # A directory this user may list but not enter
  $deny = Join-Path $OutDir "denied-$v"
  New-Item -ItemType Directory $deny -Force | Out-Null
  icacls $deny /deny "${env:USERNAME}:(X)" | Out-Null
  foreach ($c in $cases) {
    RunRuby $r 'cases.rb' "$c r.txt `"$deny`"" 'r.txt' 120
    $o = Select-String -Path stdout.txt -Pattern "MARK-OUT-$c" -Quiet
    $e = Select-String -Path stderr.txt -Pattern "MARK-ERR-$c" -Quiet
    $child = Select-String -Path stdout.txt -Pattern "CHILD-MARK-$c" -Quiet
    Log "   reached files out/err/child=$o/$e/$child"
  }
  Remove-Item case-out-*.txt, created-*.txt -Force -ErrorAction SilentlyContinue
  icacls $deny /remove:d $env:USERNAME | Out-Null
  Remove-Item -Recurse -Force $deny

  Log "== interrupt $v $(Get-Date -Format s)"
  foreach ($interval in '0.0005', '0.005', '0.02') {
    foreach ($kind in 'std', 'exc') {
      foreach ($run in 1..2) { RunRuby $r 'interrupt.rb' "$kind 400 r.txt $interval" 'r.txt' 240 }
    }
  }

  Log "== threads $v $(Get-Date -Format s)"
  foreach ($other in 'writer', 'spawner') {
    foreach ($mode in 'noleak', 'leak') { RunRuby $r 'threads.rb' "$other $mode r.txt" 'r.txt' 900 }
  }

  Log "== raw spawn $v $(Get-Date -Format s)"
  foreach ($mode in 'noleak', 'leak') { RunRuby $r 'raw_spawn.rb' "$mode r.txt" 'r.txt' 600 }

  Log "== exhaust $v $(Get-Date -Format s)"
  RunRuby $r 'exhaust.rb' 'r.txt' 'r.txt' 900

  Log "== interrupt during a successful spawn $v $(Get-Date -Format s)"
  foreach ($n in 1..3) { RunRuby $r 'interrupt_in_spawn.rb' 'r.txt' 'r.txt' 120 }
  foreach ($i in '0.002', '0.01') { RunRuby $r 'interrupt_successful_spawns.rb' "$i r.txt" 'r.txt' 300 }

  Log "== outer timeout and re-entry $v $(Get-Date -Format s)"
  foreach ($c in 'outer_timeout_during_wait', 'outer_timeout_during_spawn', 'reentry') {
    RunRuby $r 'outer_timeout.rb' "$c r.txt" 'r.txt' 120
  }
}

# signals.rb sends itself Ctrl-C events, so launch.rb starts it in a process group of its own
function Signals($ruby, $mode, $kind) {
  Remove-Item sig.txt -Force -ErrorAction SilentlyContinue
  $v = & $ruby -e 'print RUBY_VERSION'
  $loadArgs = @($lib) + $LoadPath | ForEach-Object { '-I'; $_ }
  & $ruby (Join-Path $PSScriptRoot 'launch.rb') sig-stdout.txt sig-stderr.txt $ruby @loadArgs (Join-Path $PSScriptRoot 'signals.rb') $mode $kind sig.txt
  if (Test-Path sig.txt) {
    Get-Content sig.txt | ForEach-Object { Log $_ }
  } else {
    $tail = (Get-Content sig-stderr.txt | Where-Object { $_ -notmatch '^\.+$' } | Select-Object -First 2) -join ' / '
    Log "NO RESULT $v $mode $kind :: $tail"
  }
}
$modes = 'default_int', 'trap_raise', 'trap_throw', 'thread_kill'
Log "== signal stress, leaking failures $(Get-Date -Format s)"
foreach ($r in $Ruby) { foreach ($mode in $modes) { foreach ($run in 1..2) { Signals $r $mode 'leak' } } }
Log "== signal stress, successful spawns $(Get-Date -Format s)"
foreach ($r in $Ruby) { foreach ($mode in $modes) { foreach ($run in 1..2) { Signals $r $mode 'ok' } } }
Log "DONE $(Get-Date -Format s)"
