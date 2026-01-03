# frozen_string_literal: true

require 'English'

RSpec.describe 'Process#wait' do
  it 'sets the global $CHILD_STATUS variable' do
    pid = Process.spawn('ruby', '-e', 'exit 0')
    Process.wait(pid)
    expect($CHILD_STATUS).not_to be_nil
    expect($CHILD_STATUS.pid).to eq(pid)
  end
end

RSpec.describe 'Process#wait2' do
  it 'returns a non-nil status' do
    pid = Process.spawn('ruby', '-e', 'exit 0')
    _pid, status = Process.wait2(pid)
    expect(status).not_to be_nil
    expect(status.pid).to eq(pid)
  end
end
