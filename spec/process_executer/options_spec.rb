# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::Options do
  let(:options) { ProcessExecuter::Options.new(**options_hash) }
  let(:options_hash) { {} }

  describe '#initialize' do
    subject { options }
    context 'when no options are given' do
      let(:options_hash) { {} }
      it 'should have no options' do
        expect(subject.to_h).to eq({})
      end
    end

    context 'when a single unknown option is given' do
      let(:options_hash) { { unknown: true } }
      it 'should raise an error' do
        expect { options }.to raise_error(ArgumentError, 'Unknown option: unknown')
      end
    end

    context 'when a multiple unknown option is given' do
      let(:options_hash) { { unknown1: true, unknown2: false } }
      it 'should raise an error' do
        expect { options }.to raise_error(ArgumentError, 'Unknown options: unknown1, unknown2')
      end
    end
  end

  describe '#allowed_options' do
    subject { options.allowed_options }

    it 'should not define any options' do
      expect(subject.keys.size).to eq(0)
    end
  end

  describe '#to_s' do
    subject { options.to_s }

    it 'should include the class name' do
      expect(subject).to start_with('#<ProcessExecuter::Options:')
    end

    it 'should include the memory address' do
      expect(subject).to match(/:0x[0-9a-fA-F]+ /)
    end

    it 'should include the options' do
      expect(subject).to end_with(" #{options.to_h.inspect}>")
    end
  end

  describe '#inspect' do
    subject { options.inspect }

    it 'should list the options' do
      expect(subject).to eq(options.to_h.inspect)
    end
  end

  describe 'to_h' do
    subject { options.to_h }

    it 'should return a copy of the hash of the options' do
      expect(subject).to eq(options_hash)
      expect(subject.object_id).not_to eq(options_hash.object_id)
    end
  end

  context 'with a class derived from ProcessExecuter::Options' do
    context 'with one defined option "an_option"' do
      let(:described_class) do
        v = validator

        Class.new(ProcessExecuter::Options) do
          private

          define_method(:injected_validator) { v }

          def define_options
            [
              *super,
              ProcessExecuter::OptionDefinition.new(:an_option, default: 'default', validator: injected_validator)
            ]
          end
        end
      end

      let(:validator) { nil }

      let(:options) { described_class.new(**options_hash) }

      describe '#initialize' do
        subject { options }

        describe 'option accessors' do
          it 'should have defined accessors for the defined option' do
            expect(subject).to respond_to(:an_option)
            expect(subject).to respond_to(:an_option=)
          end

          describe '#an_option' do
            subject { options.an_option }
            it 'should return the default value' do
              expect(subject).to eq('default')
            end
          end

          describe '#an_option=' do
            subject { options.an_option = 'new_value' }
            it 'should set the value of the option' do
              expect { subject }.to change { options.an_option }.to('new_value')
            end
          end
        end

        context 'when the defined option is given' do
          describe '#an_option' do
            let(:options_hash) { { an_option: 'new_value' } }
            it 'should have the given value' do
              expect(subject.an_option).to eq('new_value')
            end
          end
        end
      end

      describe '#allowed_options' do
        subject { options.allowed_options }
        it 'should return the defined option' do
          expect(subject).to match(
            an_option: having_attributes(name: :an_option, default: 'default', validator: nil)
          )
        end
      end

      describe '#to_s' do
        subject { options.to_s }

        it 'should include the class name' do
          expect(subject).to match(/^#<#<Class:0x[0-9A-Fa-f]+>:/)
        end

        it 'should include the memory address' do
          expect(subject).to match(/:0x[0-9a-fA-F]+/)
        end

        it 'should include the options' do
          expect(subject).to end_with(" #{options.to_h.inspect}>")
        end
      end

      describe '#inspect' do
        subject { options.inspect }

        it 'should list the options' do
          expect(subject).to eq(options.to_h.inspect)
        end
      end

      describe 'to_h' do
        subject { options.to_h }

        it 'should return a copy of the hash of the options' do
          expect(subject).to eq({ an_option: 'default' })
        end
      end

      context 'when an_option has a validator' do
        subject { options }

        let(:validator) do
          lambda {
            unless an_option.is_a?(String)
              raise(
                ArgumentError,
                "an_option must be a string but was #{an_option.inspect}"
              )
            end
          }
        end

        context 'when the option is set to a valid value' do
          let(:options_hash) { { an_option: 'new_value' } }

          it 'should not raise an error' do
            expect { subject }.not_to raise_error
          end
        end

        context 'when the option is set to an invalid value' do
          let(:options_hash) { { an_option: 123 } }

          it 'should raise an ArgumentError' do
            expect { subject }.to raise_error(ArgumentError, 'an_option must be a string but was 123')
          end
        end
      end
    end
  end

  context 'with a class which is derived from another class which derives from ProcessExecuter::Options' do
    let(:described_class) do
      class1 = Class.new(ProcessExecuter::Options) do
        private

        def define_options
          [
            *super,
            ProcessExecuter::OptionDefinition.new(:option1, default: 'default1', validator: -> { validate_option1 })
          ]
        end

        def validate_option1
          raise ArgumentError, 'option1 must be a String' unless option1.is_a?(String)
        end
      end

      Class.new(class1) do
        private

        define_method(:injected_validator2) { validator2 }

        def define_options
          [
            *super,
            ProcessExecuter::OptionDefinition.new(:option2, default: 2, validator: -> { validate_option2 })
          ]
        end

        def validate_option2
          raise ArgumentError, 'option2 must be an Integer' unless option2.is_a?(Integer)
        end
      end
    end

    let(:options) { described_class.new(**options_hash) }

    let(:options_hash) { {} }

    describe '#initialize' do
      subject { options }

      describe 'option accessors' do
        it 'should have defined accessors for option1' do
          expect(subject).to respond_to(:option1)
          expect(subject).to respond_to(:option1=)
        end

        it 'should have defined accessors for option2' do
          expect(subject).to respond_to(:option2)
          expect(subject).to respond_to(:option2=)
        end

        describe '#option1' do
          subject { options.option1 }
          it 'should return the default value of option1' do
            expect(subject).to eq('default1')
          end
        end

        describe '#option1=' do
          subject { options.option1 = 'new_value' }

          it 'should set the value of option1' do
            expect { subject }.to(change { options.option1 }.to('new_value'))
          end

          it 'should not change the value of option2' do
            expect { subject }.not_to(change { options.option2 })
          end
        end

        describe '#option2' do
          subject { options.option2 }

          it 'should return the default value of option2' do
            expect(subject).to eq(2)
          end
        end

        describe '#option2=' do
          subject { options.option2 = 'new_value' }

          it 'should not change the value of option1' do
            expect { subject }.not_to(change { options.option1 })
          end

          it 'should set the value of option2' do
            expect { subject }.to(change { options.option2 }.to('new_value'))
          end
        end
      end

      describe 'validators' do
        context 'when given valid option values' do
          let(:options_hash) { { option1: 'value1', option2: 2 } }

          it 'should not raise an error' do
            expect { subject }.not_to raise_error
          end
        end

        context 'when given an invalid value for option1' do
          let(:options_hash) { { option1: 123, option2: 2 } }

          it 'should raise an ArgumentError' do
            expect { subject }.to raise_error(ArgumentError, 'option1 must be a String')
          end
        end

        context 'when given an invalid value for option2' do
          let(:options_hash) { { option1: 'value1', option2: 'invalid' } }

          it 'should raise an ArgumentError' do
            expect { subject }.to raise_error(ArgumentError, 'option2 must be an Integer')
          end
        end
      end
    end
  end
end

#   it 'should define defaults for all options' do
#     expect(described_class::DEFAULTS.keys).to match_array(described_class::ALL_OPTIONS)
#   end

#   let(:options) { ProcessExecuter::Options.new(**options_hash) }

#   let(:all_options_hash) do
#     # :nocov:
#     # JRuby does not count the following as covered even though it is
#     {
#       in: double('in'),
#       out: double('out'),
#       err: double('err'),
#       unsetenv_others: double('unsetenv_others'),
#       pgroup: double('pgroup'),
#       new_pgroup: double('new_pgroup'),
#       rlimit_resourcename: double('rlimit_resourcename'),
#       umask: double('umask'),
#       close_others: double('close_others'),
#       chdir: double('chdir'),
#       timeout_after: 0,
#       raise_errors: true
#     }
#     # :nocov:
#   end

#   describe '#initialize' do
#     subject { options }

#     context 'with no options' do
#       let(:options_hash) { {} }
#       it { is_expected.to have_attributes(ProcessExecuter::Options::DEFAULTS) }
#     end

#     context 'with an option that is an Integer' do
#       let(:options_hash) { { 1 => $stdout, 2 => $stderr } }

#       it 'should not raise an Exception' do
#         expect { subject }.not_to raise_error
#       end
#     end

#     context 'with all valid options' do
#       let(:options_hash) { all_options_hash }

#       it 'should test all options' do
#         # This is to make sure that the options hash includes all options
#         expect(options_hash.keys).to match_array(ProcessExecuter::Options::ALL_OPTIONS)
#       end

#       it 'should have the expected values of all options' do
#         expect(subject).to have_attributes(options_hash)
#       end
#     end

#     context 'with an unknown option' do
#       let(:options_hash) { { unknown_option: true } }
#       it 'should raise an ArgumentError' do
#         expect { options }.to raise_error(ArgumentError, 'Unknown options: unknown_option')
#       end
#     end
#   end

#   describe '#spawn_options' do
#     subject { options.spawn_options }

#     context 'when no options are given' do
#       let(:options_hash) { {} }
#       it { is_expected.to eq({}) }
#     end

#     context 'when all options are given' do
#       let(:options_hash) { all_options_hash }
#       let(:expected_spawn_options) do
#         all_options_hash.slice(*ProcessExecuter::Options::SPAWN_OPTIONS)
#       end
#       it { is_expected.to eq(expected_spawn_options) }
#     end

#     context 'when an integer options is given' do
#       let(:options_hash) { { 1 => $stdout, 2 => $stderr } }

#       it 'should be included in the spawn_options' do
#         expect(subject).to include(1 => $stdout, 2 => $stderr)
#       end
#     end

#     context 'when an IO option is given' do
#       let(:options_hash) { { $stdout => $stdout } }

#       it 'should be included in the spawn_options' do
#         expect(subject).to include($stdout => $stdout)
#       end
#     end
#   end
# end
