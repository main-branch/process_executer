# frozen_string_literal: true

require 'English'

RSpec.describe 'Process#wait' do
  it 'sets the global $CHILD_STATUS variable' do
    pid = Process.spawn('ruby', '-e', 'exit 0')
    Process.wait(pid)
    expect($CHILD_STATUS).not_to be_nil
    expect($CHILD_STATUS.pid).to eq(pid)
  end

  it 'reports the exit status of a child that failed' do
    pid = Process.spawn('ruby', '-e', 'exit 42')
    Process.wait(pid)
    expect($CHILD_STATUS&.exitstatus).to eq(42)
  end

  it 'blocks until the child exits' do
    pid = Process.spawn('ruby', '-e', 'sleep 2')
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Process.wait(pid)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expect(elapsed).to be >= 1.5
  end
end

RSpec.describe 'Process#wait2' do
  it 'returns a non-nil status' do
    pid = Process.spawn('ruby', '-e', 'exit 0')
    _pid, status = Process.wait2(pid)
    expect(status).not_to be_nil
    expect(status.pid).to eq(pid)
  end

  it 'returns the pid and status of a child that failed' do
    pid = Process.spawn('ruby', '-e', 'exit 42')
    reaped_pid, status = Process.wait2(pid)
    expect(reaped_pid).to eq(pid)
    expect(status&.exitstatus).to eq(42)
  end
end
