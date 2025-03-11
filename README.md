# The ProcessExecuter Gem

[![Gem Version](https://badge.fury.io/rb/process_executer.svg)](https://badge.fury.io/rb/process_executer)
[![Documentation](https://img.shields.io/badge/Documentation-Latest-green)](https://rubydoc.info/gems/process_executer/)
[![Change Log](https://img.shields.io/badge/CHANGELOG-Latest-green)](https://rubydoc.info/gems/process_executer/file/CHANGELOG.md)
[![Build Status](https://github.com/main-branch/process_executer/actions/workflows/continuous-integration.yml/badge.svg)](https://github.com/main-branch/process_executer/actions/workflows/continuous-integration.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/0b5c67e5c2a773009cd0/maintainability)](https://codeclimate.com/github/main-branch/process_executer/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/0b5c67e5c2a773009cd0/test_coverage)](https://codeclimate.com/github/main-branch/process_executer/test_coverage)
[![Conventional
Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Slack](https://img.shields.io/badge/slack-main--branch/process__executer-yellow.svg?logo=slack)](https://main-branch.slack.com/archives/C07NG2BPG8Y)

ProcessExecuter provides an enhanced API for executing commands in subprocesses,
extending Ruby's built-in `Process.spawn` functionality with additional features like
capturing output, handling timeouts, streaming output to multiple destinations, and
providing detailed result information.

## Requirements

* Ruby 3.1.0 or later
* Compatible with MRI 3.1+, TruffleRuby 24+, and JRuby 9.4+
* Works on Mac, Linux, and Windows platforms

## Table of Contents

* [Requirements](#requirements)
* [Table of Contents](#table-of-contents)
* [Usage](#usage)
    * [ProcessExecuter::MonitoredPipe](#processexecutermonitoredpipe)
    * [ProcessExecuter::Result](#processexecuterresult)
    * [ProcessExecuter.spawn\_and\_wait](#processexecuterspawn_and_wait)
    * [ProcessExecuter.run](#processexecuterrun)
* [Installation](#installation)
* [Contributing](#contributing)
    * [Reporting Issues](#reporting-issues)
    * [Developing](#developing)
    * [Commit message guidelines](#commit-message-guidelines)
    * [Pull request guidelines](#pull-request-guidelines)
    * [Releasing](#releasing)
* [License](#license)

## Usage

[Full YARD documentation](https://rubydoc.info/gems/process_executer/) for this gem
is hosted on RubyGems.org. Read below for an overview and several examples.

This gem contains two public classes and two public methods:

Classes:

* `ProcessExecuter::MonitoredPipe`: allows use of any object with a `#write` method
  or an array of objects as a redirection destination in `Process.spawn`
* `ProcessExecuter::Result`: an extension of `Process::Status` that includes more
  information about the subprocess including timeout status, the command that was
  run, the subprocess options given, and (in some cases) stdout and stderr captured
  from the subprocess.

Methods:

* `ProcessExecuter.spawn_and_wait`: execute a subprocess and wait for it to exit with
  an optional timeout. Supports the same interface and features as `Process.spawn`.
* `ProcessExecuter.run`: builds upon `.spawn_and_wait` adding (1) automatically
  wrapping stdout and stderr destinations (if given) in a `MonitoredPipe` and (2)
  raises errors for any problem executing the subprocess (can be turned off).

### ProcessExecuter::MonitoredPipe

`ProcessExecuter::MonitoredPipe` objects can be used as a redirection destination for
`Process.spawn` to stream output from a subprocess to one or more destinations.
Destinations are given in this class's initializer.

The destinations are all the redirection destinations allowed by `Process.spawn` plus
the following:

* Any object with a #write method even if it does not have a file descriptor (like
  instances of StringIO)
* An array of destinations so that output can be tee'd to several sources

Example of capturing stdout to a StringIO (which is not directly possible with
`Process.spawn`):

```ruby
require 'stringio'
require 'process_executer'

output_buffer = StringIO.new
out_pipe = ProcessExecuter::MonitoredPipe.new(output_buffer)
pid, status = Process.wait2(Process.spawn('echo "Hello World"', out: out_pipe))
out_pipe.close # Close the pipe so all the data is flushed and resources are not leaked
output_buffer.string #=> "Hello World\n"
```

Any object that implements `#write` can be used as a destination (not just StringIO).
For instance, you can use it to parse process output as a stream which might be useful
for long XML or JSON output.

Example of tee'ing stdout to multiple destinations:

```ruby
require 'stringio'
require 'process_executer'

output_buffer = StringIO.new
output_file = File.open('process.out', 'w')
out_pipe = ProcessExecuter::MonitoredPipe.new([:tee, output_buffer, output_file])
pid, status = Process.wait2(Process.spawn('echo "Hello World"', out: out_pipe))
out_pipe.close
output_file.close
output_buffer.string #=> "Hello World\n"
File.read('process.out') #=> "Hello World\n"
```

### ProcessExecuter::Result

An instance of this class is returned from both `.spawn_and_wait` and `.run`.

This class is an extension of
[Process::Status](https://docs.ruby-lang.org/en/3.3/Process/Status.html) so it
supports the same interface with the following additions:

* `#command`: the command given to `.spawn_and_wait` or `.run`
* `#options`: the options given to `.spawn_and_wait` or `.run` (possibly with some
  changes)
* `#timed_out?`: true if the process was killed after running for `:timeout_after`
  seconds
* `#elapsed_time`: the number of seconds the process was running
* `#stdout`: the captured stdout from the subprocess (if the stdout destination was
  wrapped by a `MonitoredPipe`)
* `#stderr`: the captured stderr from the subprocess (if the stderr destination was
  wrapped by a `MonitoredPipe`)

### ProcessExecuter.spawn_and_wait

`ProcessExecuter.spawn_and_wait` has the same interface and features as
[Process.spawn](https://docs.ruby-lang.org/en/3.3/Process.html#method-c-spawn)
with the following differences:

1. It waits for the subprocess to exit
2. A timeout can be specified using the `:timeout_after` option
3. It returns a `ProcessExecuter::Result` instead of a `Process::Status`

If the command does not terminate before the number of seconds specified by
`:timeout_after`, the process is killed by sending it the SIGKILL signal. The
returned Result object's `timed_out?` attribute will return `true`. For example:

```ruby
result = ProcessExecuter.spawn_and_wait('sleep 10', timeout_after: 0.01)
result.signaled? #=> true
result.termsig #=> 9
result.timed_out? #=> true
```

If the destination for stdout and stderr are wrapped by a
ProcessExecuter::MonitoredPipe, the result will return the stdout and stderr
subprocess output from its `#stdout` and `#stderr` methods.

### ProcessExecuter.run

`ProcessExecuter.run` builds upon `ProcessExecuter.spawn_and_wait` adding the
following features:

* It automatically wraps any given stdout and stderr destination with a
  MonitoredPipe. The pipe will be closed when the command exits.
* It raises an error if there is any problem with the subprocess. This behavior can
  be turned off with the `raise_errors: false` option.

```ruby
result = ProcessExecuter.run('echo "Hello World"', out: StringIO.new)
result.stdout #=> "Hello World\n"
```

## Installation

Install the gem and add to the application's Gemfile by executing:

```shell
bundle add process_executer
```

If bundler is not being used to manage dependencies, install the gem by executing:

```shell
gem install process_executer
```

## Contributing

### Reporting Issues

Bug reports and other support requests are welcome on [this project's
GitHub issue tracker](https://github.com/main-branch/process_executer)

### Developing

Clone the repo, run `bin/setup` to install dependencies, and then run `rake spec` to
run the tests. You can also run `bin/console` for an interactive prompt that will
allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

### Commit message guidelines

All commit messages must follow the [Conventional Commits
standard](https://www.conventionalcommits.org/en/v1.0.0/). This helps us maintain a
clear and structured commit history, automate versioning, and generate changelogs
effectively.

To ensure compliance, this project includes:

* A git commit-msg hook that validates your commit messages before they are accepted.

  To activate the hook, you must have node installed and run `npm install`.

* A GitHub Actions workflow that will enforce the Conventional Commit standard as
  part of the continuous integration pipeline.

  Any commit message that does not conform to the Conventional Commits standard will
  cause the workflow to fail and not allow the PR to be merged.

### Pull request guidelines

All pull requests must be merged using rebase merges. This ensures that commit
messages from the feature branch are preserved in the release branch, keeping the
history clean and meaningful.

### Releasing

In the root directory of this project with the `main` branch checked out, run
the following command:

```shell
create-github-release {major|minor|patch}
```

Follow the directions given by the `create-github-release` to publish the new version
of the gem.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
