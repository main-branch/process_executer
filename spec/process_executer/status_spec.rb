# frozen_string_literal: true

RSpec.describe ProcessExecuter::Status do
  let(:expected_pid) { 999 }

  let(:status_exit0) { described_class.new(expected_pid, 0) }
  let(:status_exit99) { described_class.new(expected_pid, 25_344) }
  let(:status_signaled9) { described_class.new(expected_pid, 9) }
  let(:status_signaled11_coredump) { described_class.new(expected_pid, 139) }
  let(:status_stopped_signal17) { described_class.new(expected_pid, 4_479) }

  describe '#initialize' do
    context 'when process exits with exitstatus 99' do
      subject { status_exit99 }
      it { is_expected.to have_attributes(pid: expected_pid, stat: 25_344) }
    end
  end

  describe '#&' do
    context 'with process has uncaught signal 11 and coredump' do
      subject { status_signaled11_coredump & operand }
      context 'with 0b01111111' do
        let(:operand) { 0b01111111 }
        it { is_expected.to eq(11) }
      end
      context 'with 0b10000000' do
        let(:operand) { 0b10000000 }
        it { is_expected.to eq(128) }
      end
      context 'with 0b1111111100000000' do
        let(:operand) { 0b1111111100000000 }
        it { is_expected.to eq(0) }
      end
    end
  end

  describe '#==' do
    context 'with process has uncaught signal 11 and coredump' do
      subject { status_signaled11_coredump == other }
      context 'with 139' do
        let(:other) { 139 }
        it { is_expected.to eq(true) }
      end
      context 'with 0' do
        let(:other) { 0 }
        it { is_expected.to eq(false) }
      end
      context 'with a string "139"' do
        let(:other) { '139' }
        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#>>' do
    context 'with process has uncaught signal 11 and coredump' do
      subject { status_signaled11_coredump >> num }
      context 'with 0' do
        let(:num) { 0 }
        it { is_expected.to eq(139) }
      end
      context 'with 8' do
        let(:num) { 8 }
        it { is_expected.to eq(0) }
      end
    end

    context 'when process exits with exitstatus 99' do
      subject { status_exit99 >> num }
      context 'with 0' do
        let(:num) { 0 }
        it { is_expected.to eq(25_344) }
      end
      context 'with 8' do
        let(:num) { 8 }
        it { is_expected.to eq(99) }
      end
    end
  end

  describe '#coredump?' do
    subject { status.coredump? }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq(false) }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq(false) }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq(false) }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq(true) }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq(false) }
    end
  end

  describe '#exited?' do
    subject { status.exited? }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq(true) }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq(true) }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq(false) }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq(false) }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq(false) }
    end
  end

  describe '#exitstatus' do
    subject { status.exitstatus }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq(0) }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq(99) }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to be_nil }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to be_nil }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to be_nil }
    end
  end

  describe '#inspect' do
    subject { status.coredump? }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
    end
  end

  describe '#signaled?' do
    subject { status.signaled? }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq(false) }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq(false) }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq(true) }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq(true) }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq(false) }
    end
  end

  describe '#stopped?' do
    subject { status.stopped? }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq(false) }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq(false) }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq(false) }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq(false) }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq(true) }
    end
  end

  describe '#stopsig' do
    subject { status.stopsig }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to be_nil }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to be_nil }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to be_nil }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to be_nil }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq(17) }
    end
  end

  describe '#success?' do
    subject { status.success? }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq(true) }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq(false) }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to be_nil }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to be_nil }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to be_nil }
    end
  end

  describe '#termsig' do
    subject { status.termsig }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to be_nil }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to be_nil }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq(9) }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq(11) }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to be_nil }
    end
  end

  describe '#to_i' do
    subject { status.to_i }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq(0) }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq(25_344) }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq(9) }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq(139) }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq(4_479) }
    end
  end

  describe '#to_s' do
    subject { status.to_s }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq('pid 999 exit 0') }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq('pid 999 exit 99') }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq('pid 999 SIGKILL (signal 9)') }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq('pid 999 SIGSEGV (signal 11) (core dumped)') }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq('pid 999 stopped SIGSTOP (signal 17)') }
    end
  end

  describe '#inspect' do
    subject { status.inspect }
    context 'when process exits with exitstatus 0' do
      let(:status) { status_exit0 }
      it { is_expected.to eq('#<ProcessExecuter::Status pid 999 exit 0>') }
    end

    context 'when process exits with exitstatus 99' do
      let(:status) { status_exit99 }
      it { is_expected.to eq('#<ProcessExecuter::Status pid 999 exit 99>') }
    end

    context 'when process has uncaught signal 9' do
      let(:status) { status_signaled9 }
      it { is_expected.to eq('#<ProcessExecuter::Status pid 999 SIGKILL (signal 9)>') }
    end

    context 'when process has uncaught signal 11 and coredump' do
      let(:status) { status_signaled11_coredump }
      it { is_expected.to eq('#<ProcessExecuter::Status pid 999 SIGSEGV (signal 11) (core dumped)>') }
    end

    context 'when process has stopped with signal 17' do
      let(:status) { status_stopped_signal17 }
      it { is_expected.to eq('#<ProcessExecuter::Status pid 999 stopped SIGSTOP (signal 17)>') }
    end
  end
end

# pid: 29639
# stat: 11
# "pid 28796 SIGSEGV (signal 11) (core dumped)"
# "#<Process::Status: pid 28796 SIGSEGV (signal 11) (core dumped)>"

#   pid: 29639
#   stat: 11
#   "pid 29639 SIGSEGV (signal 11)"
#   "#<Process::Status: pid 29639 SIGSEGV (signal 11)>"

#   pid: 30015
#   stat: 9
#   "pid 30015 SIGKILL (signal 9)"
#   "#<Process::Status: pid 30015 SIGKILL (signal 9)>"

#   pid: 32880
#   stat: 25344
#   "pid 32880 exit 99"
#   "#<Process::Status: pid 32880 exit 99>"

#   pid: 38161
#   stat: 4479
#   "pid 38161 stopped SIGSTOP (signal 17)"
#   "#<Process::Status: pid 38161 stopped SIGSTOP (signal 17)>"

#   pid: 42420
#   stat: 0
#   "pid 42420 exit 0"
#   "#<Process::Status: pid 42420 exit 0>"
