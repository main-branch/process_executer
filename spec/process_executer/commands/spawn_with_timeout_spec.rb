# frozen_string_literal: true

require 'spec_helper'
require 'process_executer/commands/spawn_with_timeout'

RSpec.describe ProcessExecuter::Commands::SpawnWithTimeout do
  let(:command) { ['echo', 'hi'] }
  let(:options) { ProcessExecuter::Options::SpawnWithTimeoutOptions.new(timeout_after: 1) }
  let(:pid) { 1234 }

  subject(:spawn_command) do
    described_class.new(command, options).tap { |cmd| cmd.instance_variable_set(:@pid, pid) }
  end

  before do
    allow(Process).to receive(:kill)
  end

  context 'when Process.wait2 returns nil' do
    it 'falls back to other wait calls and raises ProcessIOError if still nil' do
      allow(Process).to receive(:wait2).with(pid).and_return(nil)
      allow(Process).to receive(:waitpid2).with(pid).and_return(nil)
      allow(Process).to receive(:wait).with(pid).and_return(nil)

      expect { spawn_command.wait_for_process_raw }.to raise_error(ProcessExecuter::ProcessIOError, /nil status/)
    end

    it 'uses waitpid2 fallback when available' do
      fake_status = instance_double(Process::Status)
      allow(Process).to receive(:wait2).with(pid).and_return(nil)
      allow(Process).to receive(:waitpid2).with(pid).and_return([pid, fake_status])

      status, timed_out = spawn_command.wait_for_process_raw

      expect(status).to eq(fake_status)
      expect(timed_out).to be(false)
    end
  end
end
