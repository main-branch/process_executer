# frozen_string_literal: true

require 'tmpdir'

RSpec.describe ProcessExecuter do
  it 'has a version number' do
    expect(ProcessExecuter::VERSION).not_to be nil
  end

  describe 'execute' do
    subject { ProcessExecuter.new(**options).execute(*command) }

    let(:options) { {} }

    let(:command) { %w[ruby test_script.rb] }

    before(:each) do
      @temp_dir = Dir.mktmpdir
      @saved_dir = Dir.pwd
      Dir.chdir(@temp_dir)
      File.write('test_script.rb', script)
    end

    after(:each) do
      Dir.chdir(@saved_dir)
      FileUtils.rm_rf(@temp_dir)
    end

    context 'with a simple command' do
      let(:script) { <<~SCRIPT }
        require 'fileutils'
        FileUtils.touch('test.txt')
      SCRIPT

      it 'executes the command' do
        subject
        expect(File.exist?('test.txt')).to be true
      end

      it 'returns a ProcessExecuter::Result' do
        expect(subject).to be_a(ProcessExecuter::Result)
      end

      it 'should run successfully' do
        expect(subject.status.exitstatus).to eq(0)
      end
    end

    context 'with a command that outputs to stdout' do
      let(:script) { <<~SCRIPT }
        puts('Hello World')
        STDOUT.flush
        puts('Goodbye World')
      SCRIPT

      it 'should capture stdout' do
        expect(subject.out).to eq("Hello World\nGoodbye World\n")
      end
    end

    context 'with a command that outputs to stderr' do
      let(:script) { <<~SCRIPT }
        STDERR.puts('Hello World')
        STDERR.flush
        STDERR.puts('Goodbye World')
      SCRIPT

      it 'should capture stderr' do
        expect(subject.err).to eq("Hello World\nGoodbye World\n")
      end
    end

    context 'with a command that outputs to stdout a little bit over time' do
      let(:script) { <<~SCRIPT }
        puts('Hello World')
        STDOUT.flush
        sleep 0.5
        puts('Hello?')
        STDOUT.flush
        sleep 0.5
        puts('Is this thing on?')
        STDOUT.flush
      SCRIPT

      it 'should capture everything output to stdout' do
        expect(subject.out).to eq("Hello World\nHello?\nIs this thing on?\n")
      end
    end

    context 'with a command that outputs to both stdout and stderr' do
      let(:script) { <<~SCRIPT }
        puts('Processing "Hello World"...')
        warn('Error: "Hello World" is not a valid input')
        puts('DONE WITH ERROR')
      SCRIPT

      it 'should capture stdout and stderr' do
        expect(subject.out).to eq("Processing \"Hello World\"...\nDONE WITH ERROR\n")
        expect(subject.err).to eq("Error: \"Hello World\" is not a valid input\n")
      end
    end

    context 'with a command that outputs to out and err' do
      let(:out) { 'Some output' }
      let(:err) { 'ERROR' }
      let(:expected_out) { "#{out}\n" }
      let(:expected_err) { "#{err}\n" }
      let(:nothing) { '' }

      let(:script) { <<~SCRIPT }
        puts('#{out}')
        warn('#{err}')
      SCRIPT

      describe '(testing collect_out and collect_err flags)' do
        context 'when collect_out AND collect_err are false' do
          let(:options) { { collect_out: false, collect_err: false } }
          let(:expected_out) { nil }
          let(:expected_err) { nil }

          it 'should not collect stdout and stderr in :out and :err' do
            expect(subject).to have_attributes(out: expected_out, err: expected_err)
          end
        end

        context 'when collect_out is false' do
          let(:options) { { collect_out: false } }
          let(:expected_out) { nil }

          it 'should not collect stdout in :out' do
            expect(subject).to have_attributes(out: expected_out, err: expected_err)
          end
        end

        context 'when collect_err is false' do
          let(:options) { { collect_err: false } }
          let(:expected_err) { nil }

          it 'should not collect stderr in :err' do
            expect(subject).to have_attributes(out: expected_out, err: expected_err)
          end
        end
      end

      describe '(testing passthru_out and passthru_err flags)' do
        context 'when passthru_out is true' do
          let(:options) { { passthru_out: true } }

          it 'should pass thru stdout but not stderr AND still collect both stdout and stderr' do
            result = nil
            expect { result = subject }.to(output("#{out}\n").to_stdout.and(output(nothing).to_stderr))
            expect(result).to have_attributes(out: "#{out}\n", err: "#{err}\n")
          end
        end

        context 'when passthru_err is true' do
          let(:options) { { passthru_err: true } }
          it 'should pass thru stderr but not stdout AND still collect both stdout and stderr' do
            result = nil
            expect { result = subject }.to(output(nothing).to_stdout.and(output("#{err}\n").to_stderr))
            expect(result).to have_attributes(out: "#{out}\n", err: "#{err}\n")
          end
        end

        context 'when both stdpassthru_out and stdpassthru_err are true' do
          let(:options) { { passthru_out: true, passthru_err: true } }

          it 'should pass thru stderr and stdout AND still collect both stdout and stderr' do
            result = nil
            expect { result = subject }.to(output("#{out}\n").to_stdout.and(output("#{err}\n").to_stderr))
            expect(result).to have_attributes(out: "#{out}\n", err: "#{err}\n")
          end
        end
      end
    end
  end
end
