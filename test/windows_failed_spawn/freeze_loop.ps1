# Repeats the run most likely to freeze the process (issue 210): 600 leaking failures beside a
# thread writing to stderr. Each repeat is a new Ruby process; one that has not exited after 60
# seconds is counted as frozen and stopped. Writes to <OutDir>\freeze-<Tag>.log, ending with DONE.
#
#   pwsh -File freeze_loop.ps1 -Ruby C:\path\to\ruby.exe -Runs 400 -Burners 16
#
# See README.md.
param(
  [string]$Ruby = (Get-Command ruby).Source,
  [string[]]$LoadPath = @(),
  [int]$Runs = 400,
  # Busy-loop processes to run alongside, one per core makes the race far more likely
  [int]$Burners = 0,
  [int]$BurnMinutes = 60,
  # Stop after this many frozen runs
  [int]$Want = 3,
  # Optional gdb.exe: its backtrace of every thread is saved for each frozen run
  [string]$Gdb = '',
  [string]$Tag = 'run',
  [string]$OutDir = (Join-Path $PSScriptRoot 'results')
)

$LoadPath = @($LoadPath | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$missing = @(@($Ruby) + $LoadPath | Where-Object { -not (Test-Path $_) })
if ($missing) { throw "No such path: $($missing -join ', ')" }
# Made absolute before the location changes, so a relative argument still points at the same place
$Ruby = (Resolve-Path $Ruby).Path
$LoadPath = @($LoadPath | ForEach-Object { (Resolve-Path $_).Path })
$OutDir = (New-Item -ItemType Directory $OutDir -Force).FullName

$lib = Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'lib'
Set-Location $OutDir
$log = Join-Path $OutDir "freeze-$Tag.log"
Remove-Item $log -Force -ErrorAction SilentlyContinue
function Log($s) { $s | Out-File -FilePath $log -Append -Encoding utf8 }
$include = (@($lib) + $LoadPath | ForEach-Object { "-I `"$_`"" }) -join ' '
$result = "freeze-$Tag-result.txt"

Log "START $(Get-Date -Format s) ruby=$(& $Ruby -e 'print RUBY_VERSION') runs=$Runs burners=$Burners"
$burnerProcesses = @()
foreach ($n in 1..$Burners) {
  if ($Burners -lt 1) { break }
  $burnerProcesses += Start-Process -FilePath $Ruby -ArgumentList "`"$(Join-Path $PSScriptRoot 'burn.rb')`" $BurnMinutes" -NoNewWindow -PassThru
}

$frozen = 0
$completed = 0
try {
  foreach ($run in 1..$Runs) {
    Remove-Item $result -Force -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $Ruby -ArgumentList "$include `"$(Join-Path $PSScriptRoot 'threads.rb')`" writer leak $result" `
      -NoNewWindow -PassThru -RedirectStandardOutput "freeze-$Tag-stdout.txt" -RedirectStandardError "freeze-$Tag-stderr.txt"
    if ($p.WaitForExit(60000)) {
      # A run that exits is healthy only if it wrote its result and the streams worked afterwards.
      # One that did not says nothing about freezing, so stop: the setup is wrong or the gem is.
      if (-not (Test-Path $result)) {
        # The first lines of stderr that are not the writer thread's own output
        $said = Get-Content "freeze-$Tag-stderr.txt" | Where-Object { $_ -notmatch '^(log line )+$' } | Select-Object -First 2
        Log "run $run NO RESULT (exit code $($p.ExitCode)) :: $($said -join ' / ')"
        break
      }
      $line = Get-Content $result
      if ($line -notmatch 'afterwards out=ok err=ok') {
        Log "run $run UNHEALTHY $line"
        break
      }
      $completed++
      if ($run % 25 -eq 0) { Log "run $run ok so far, frozen=$frozen" }
      continue
    }
    $frozen++
    if ($Gdb) { & $Gdb -p $p.Id -batch -ex 'set pagination off' -ex 'thread apply all bt 12' *> "freeze-$Tag-$run-backtrace.txt" }
    Stop-Process -Id $p.Id -Force
    Log "run $run FROZEN"
    if ($frozen -ge $Want) { break }
  }
} finally {
  # Only the burners this script started, by process id
  $burnerProcesses | Where-Object { -not $_.HasExited } | ForEach-Object { Stop-Process -Id $_.Id -Force }
}
Log "DONE $(Get-Date -Format s) frozen=$frozen healthy=$completed of $Runs"
