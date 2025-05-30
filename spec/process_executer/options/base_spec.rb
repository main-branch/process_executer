# frozen_string_literal: true

require 'stringio'

RSpec.describe ProcessExecuter::Options::Base do
  let(:options) { ProcessExecuter::Options::Base.new(**options_hash) }
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
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { options }.to raise_error(ProcessExecuter::ArgumentError, 'Unknown option: unknown')
      end
    end

    context 'when multiple unknown options are given' do
      let(:options_hash) { { unknown1: true, unknown2: false } }
      it 'should raise a ProcessExecuter::ArgumentError' do
        expect { options }.to raise_error(ProcessExecuter::ArgumentError, 'Unknown options: unknown1, unknown2')
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

  describe '#with' do
    let(:described_class) do
      Class.new(ProcessExecuter::Options::Base) do
        private

        def define_options
          [
            *super,
            ProcessExecuter::Options::OptionDefinition.new(:option1, default: 'value1'),
            ProcessExecuter::Options::OptionDefinition.new(:option2, default: 'value2')
          ]
        end
      end
    end

    let(:original_options) { described_class.new }

    subject { original_options.merge(*other_options_hashes) }

    context 'when given no options to update' do
      let(:other_options_hashes) { [] }

      it 'should return the same instance' do
        expect(subject.option1).to eq('value1')
        expect(subject.option2).to eq('value2')
      end
    end

    context 'when given one option to update' do
      let(:other_options_hashes) { [{ option1: 'new_value1' }] }

      it 'should return a new instance with the new options' do
        expect(subject).to have_attributes(option1: 'new_value1', option2: 'value2')
      end

      it 'should not change the original instance' do
        expect(original_options).to have_attributes(option1: 'value1', option2: 'value2')
      end
    end

    context 'when given new options which are the same as the original options' do
      let(:other_options_hashes) { [{ option1: 'new_value1', option2: 'new_value2' }] }

      it 'should return a new instance with the new options' do
        expect(subject).to have_attributes(option1: 'new_value1', option2: 'new_value2')
      end
    end

    context 'when given multiple options hashes' do
      let(:other_options_hashes) { [other_options_hash1, other_options_hash2] }
      let(:other_options_hash1) { { option1: 'new_value1' } }
      let(:other_options_hash2) { { option1: 'Last one wins!' } }

      it 'should return a new instance with the new options' do
        expect(subject).to have_attributes(option1: 'Last one wins!', option2: 'value2')
      end
    end
  end

  context 'with a class derived from ProcessExecuter::Options::Base' do
    context 'with one defined option "an_option"' do
      let(:described_class) do
        v = validator

        Class.new(ProcessExecuter::Options::Base) do
          private

          define_method(:injected_validator) { v }

          def define_options
            [
              *super,
              ProcessExecuter::Options::OptionDefinition.new(:an_option, default: 'default',
                                                                         validator: injected_validator)
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
          end

          describe '#an_option' do
            subject { options.an_option }
            it 'should return the default value' do
              expect(subject).to eq('default')
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
          lambda { |_key, _value|
            unless an_option.is_a?(String)
              raise(
                ProcessExecuter::ArgumentError,
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

          it 'should raise an ProcessExecuter::ArgumentError' do
            expect { subject }.to(
              raise_error(ProcessExecuter::ArgumentError, 'an_option must be a string but was 123')
            )
          end
        end
      end
    end
  end

  context 'with a class which is derived from another class which derives from ProcessExecuter::Options' do
    let(:described_class) do
      class1 = Class.new(ProcessExecuter::Options::Base) do
        private

        def define_options
          [
            *super,
            ProcessExecuter::Options::OptionDefinition.new(:option1, default: 'default1', validator: lambda {
              |_key, _value| validate_option1
            })
          ]
        end

        def validate_option1
          errors << 'option1 must be a String' unless option1.is_a?(String)
        end
      end

      Class.new(class1) do
        private

        define_method(:injected_validator2) { validator2 }

        def define_options
          [
            *super,
            ProcessExecuter::Options::OptionDefinition.new(
              :option2,
              default: 2,
              validator: ->(_key, _value) { validate_option2 }
            )
          ]
        end

        def validate_option2
          errors << 'option2 must be an Integer' unless option2.is_a?(Integer)
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
        end

        it 'should have defined accessors for option2' do
          expect(subject).to respond_to(:option2)
        end

        describe '#option1' do
          subject { options.option1 }
          it 'should return the default value of option1' do
            expect(subject).to eq('default1')
          end
        end

        describe '#option2' do
          subject { options.option2 }

          it 'should return the default value of option2' do
            expect(subject).to eq(2)
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

          it 'should raise an ProcessExecuter::ArgumentError' do
            expect { subject }.to raise_error(ProcessExecuter::ArgumentError, 'option1 must be a String')
          end
        end

        context 'when given an invalid value for option2' do
          let(:options_hash) { { option1: 'value1', option2: 'invalid' } }

          it 'should raise an ProcessExecuter::ArgumentError' do
            expect { subject }.to raise_error(ProcessExecuter::ArgumentError, 'option2 must be an Integer')
          end
        end

        context 'when given an invalid value for both option1 and option2' do
          let(:options_hash) { { option1: 123, option2: 'invalid' } }

          it 'should raise an ProcessExecuter::ArgumentError' do
            expect do
              subject
            end.to raise_error(ProcessExecuter::ArgumentError, "option1 must be a String\noption2 must be an Integer")
          end
        end
      end
    end
  end
end
