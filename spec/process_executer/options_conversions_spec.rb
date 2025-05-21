# frozen_string_literal: true

# # frozen_string_literal: true

# RSpec.describe ProcessExecuter do
#   describe '.spawn_options' do
#     subject { ProcessExecuter.spawn_options(given_options) }

#     context 'when given options is a Hash' do
#       let(:given_options) { { out: $stdout } }
#       it 'should return a SpawnOptions object with the same options' do
#         expect(subject).to be_a(ProcessExecuter::Options::SpawnOptions)
#         expect(subject.to_h).to include(given_options)
#       end
#     end

#     context 'when given options is a ProcessExecuter::Options::SpawnOptions' do
#       let(:given_options) { ProcessExecuter::Options::SpawnOptions.new(out: $stdout) }
#       it 'should return the given object' do
#         expect(subject.object_id).to eq(given_options.object_id)
#       end
#     end

#     context 'when given options any other kind of option' do
#       let(:given_options) { Object.new }
#       it 'should raise an ProcessExecuter::ArgumentError' do
#         expect { subject }.to raise_error(ProcessExecuter::ArgumentError)
#       end
#     end
#   end

#   describe '.spawn_and_wait_options' do
#     subject { ProcessExecuter.spawn_with_timeout_options(given_options) }

#     context 'when given options is a Hash' do
#       let(:given_options) { { timeout_after: 10 } }
#       it 'should return a SpawnWithTimeoutOptions object with the same options' do
#         expect(subject).to be_a(ProcessExecuter::Options::SpawnWithTimeoutOptions)
#         expect(subject.to_h).to include(given_options)
#       end
#     end

#     context 'when given options is a ProcessExecuter::Options::SpawnAndWaitOptions' do
#       let(:given_options) { ProcessExecuter::Options::SpawnAndWaitOptions.new(timeout_after: 10) }
#       it 'should return the given object' do
#         expect(subject.object_id).to eq(given_options.object_id)
#       end
#     end

#     context 'when given options any other kind of option' do
#       let(:given_options) { Object.new }
#       it 'should raise an ProcessExecuter::ArgumentError' do
#         expect { subject }.to raise_error(ProcessExecuter::ArgumentError)
#       end
#     end
#   end

#   describe '.run_options' do
#     subject { ProcessExecuter.run_options(given_options) }

#     context 'when given options is a Hash' do
#       let(:given_options) { { logger: Logger.new(nil) } }
#       it 'should return a RunOptions object with the same options' do
#         expect(subject).to be_a(ProcessExecuter::Options::RunOptions)
#         expect(subject.to_h).to include(given_options)
#       end
#     end

#     context 'when given options is a ProcessExecuter::Options::RunOptions' do
#       let(:given_options) { ProcessExecuter::Options::RunOptions.new(logger: Logger.new(nil)) }
#       it 'should return the given object' do
#         expect(subject.object_id).to eq(given_options.object_id)
#       end
#     end

#     context 'when given options any other kind of option' do
#       let(:given_options) { Object.new }
#       it 'should raise an ProcessExecuter::ArgumentError' do
#         expect { subject }.to raise_error(ProcessExecuter::ArgumentError)
#       end
#     end
#   end
# end
