# frozen_string_literal: true

RSpec.describe ProcessExecuter::Process do
  let(:process) { ProcessExecuter::Process.new(*command, **spawn_options) }
  let(:command) { %w[echo foobar] }
  let(:spawn_options) { { in: double, out: double } }
  let(:pid) { 999 }
  let(:status) { double('status') }

  describe '#initialize' do
    subject { process }
    before do
      expect(Process).to receive(:spawn).with(*command, **spawn_options).and_return(pid)
    end

    it 'should spawn a process' do
      subject
    end
  end

  describe '#pid' do
    subject { process.pid }
    before do
      expect(Process).to receive(:spawn).with(*command, **spawn_options).and_return(pid)
    end

    it "should be set to the spawned process's pid" do
      expect(subject).to eq(pid)
    end
  end

  describe '#status' do
    subject { process.status }
    before do
      expect(Process).to receive(:spawn).with(*command, **spawn_options).and_return(pid)
    end

    context 'before terminated? has been called' do
      it 'should be nil' do
        expect(subject).to be_nil
      end
    end

    context 'when terminated? has not returned true' do
      before do
        expect(Process).to receive(:wait2).with(pid, Process::WNOHANG).and_return([pid, nil])
      end

      it 'should be nil' do
        expect(process.terminated?).to eq(false)
        expect(subject).to be_nil
      end
    end

    context 'when terminated has returned true' do
      before do
        expect(Process).to receive(:wait2).with(pid, Process::WNOHANG).and_return([pid, status])
      end

      it 'should return the exit status of the process' do
        expect(process.terminated?).to eq(true)
        expect(subject).to eq(status)
      end
    end
  end

  describe '#terminated?' do
    subject { process.terminated? }

    before do
      expect(Process).to receive(:spawn).with(*command, **spawn_options).and_return(pid)
    end

    context 'when the process has not terminated' do
      before do
        expect(Process).to receive(:wait2).with(pid, Process::WNOHANG).and_return([pid, nil])
      end

      it 'should return false' do
        expect(subject).to eq(false)
      end
    end

    context 'when the process has terminated' do
      before do
        expect(Process).to receive(:wait2).with(pid, Process::WNOHANG).and_return([pid, status])
      end

      it 'should return true' do
        expect(subject).to eq(true)
      end
    end

    context 'when called multiple times after the process has terminated' do
      before do
        expect(Process).to receive(:wait2).with(pid, Process::WNOHANG).and_return([pid, status]).once
      end

      it 'should not check if the process is terminated again' do
        expect(subject).to eq(true)
        expect(subject).to eq(true)
      end
    end
  end
end
