# The ProcessExecuter Gem

[![Gem Version](https://badge.fury.io/rb/process_executer.svg)](https://badge.fury.io/rb/process_executer)
[![Documentation](https://img.shields.io/badge/Documentation-Latest-green)](https://rubydoc.info/gems/process_executer/)
[![Change Log](https://img.shields.io/badge/CHANGELOG-Latest-green)](https://rubydoc.info/gems/process_executer/file/CHANGELOG.md)
[![Build Status](https://github.com/main-branch/process_executer/actions/workflows/continuous-integration.yml/badge.svg)](https://github.com/main-branch/process_executer/actions/workflows/continuous-integration.yml)
[![Conventional
Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Slack](https://img.shields.io/badge/slack-main--branch/process__executer-yellow.svg?logo=slack)](https://main-branch.slack.com/archives/C07NG2BPG8Y)

ProcessExecuter provides an enhanced API for executing commands in subprocesses,
extending Ruby's built-in `Process.spawn` functionality.

It has additional features like capturing output, handling timeouts, streaming output
to multiple destinations, and providing detailed result information.

This README documents the HEAD version of process_executer which may contain
unrelease information. To see the README for the version you are using, consult
RubyGems.org. Go to the [process_executer page in
RubyGems.org](https://rubygems.org/gems/process_executer), select your version, and
then click the "Documentation" link.

## Requirements

- Ruby 3.1.0 or later
- Compatible with MRI 3.1+, TruffleRuby 24+, and JRuby 9.4+
- Works on Mac, Linux, and Windows platforms

## Table of Contents

- [Requirements](#requirements)
- [Table of Contents](#table-of-contents)
- [Usage](#usage)
  - [Key Methods](#key-methods)
    - [ProcessExecuter.spawn\_with\_timeout](#processexecuterspawn_with_timeout)
    - [ProcessExecuter.run](#processexecuterrun)
    - [ProcessExecuter.run\_with\_capture](#processexecuterrun_with_capture)
  - [Key Classes](#key-classes)
    - [ProcessExecuter::MonitoredPipe](#processexecutermonitoredpipe)
- [Breaking Changes](#breaking-changes)
  - [2.x](#2x)
    - [`ProcessExecuter.spawn`](#processexecuterspawn)
    - [`ProcessExecuter.run`](#processexecuterrun-1)
    - [`ProcessExecuter::Result`](#processexecuterresult)
    - [Other](#other)
  - [3.x](#3x)
    - [`ProcessExecuter.run`](#processexecuterrun-2)
  - [4.x](#4x)
    - [`ProcessExecuter.spawn_and_wait`](#processexecuterspawn_and_wait)
    - [`ProcessExecuter::Result`](#processexecuterresult-1)
    - [`ProcessExecuter.spawn_and_wait_with_options`](#processexecuterspawn_and_wait_with_options)
    - [`ProcessExecuter.run_with_options`](#processexecuterrun_with_options)
    - [Other](#other-1)
- [Installation](#installation)
- [Contributing](#contributing)
  - [Reporting Issues](#reporting-issues)
  - [Developing](#developing)
  - [Commit message guidelines](#commit-message-guidelines)
  - [Pull request guidelines](#pull-request-guidelines)
  - [Releasing](#releasing)
- [License](#license)

## Usage

[Full YARD documentation](https://rubydoc.info/gems/process_executer/) for this gem
is hosted on RubyGems.org. Read below for an overview and several examples.

This gem contains the following important classes and

### Key Methods

The following methods all run a command in a subprocess. They accept the same
arguments and a superset of the options as
[`Process.spawn`](https://docs.ruby-lang.org/en/3.3/Process.html#method-c-spawn).
They return an object that is a superset of `Process::Status`.

#### ProcessExecuter.spawn_with_timeout

Has the functionality of `Process.spawn` plus:

1. Blocks until the command completes
2. Allows a timeout to be given with the `timeout_after: <Numeric seconds>` option
   (default is no timeout)
3. Returns a `ProcessExecuter::Result` which has the same attributes as
   [`Process::Status`](https://docs.ruby-lang.org/en/3.4/Process/Status.html) plus
   additional attributes for `elapsed_time`, `timed_out?`, the `command` that was
   run, and the `options` given.

If the command does not terminate before the number of seconds specified by
`:timeout_after`, the process is killed by sending it the SIGKILL signal. The
returned object's `timed_out?` attribute will return `true`. For example:

```ruby
result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 0.01)
result.signaled? #=> true
result.termsig #=> 9
result.timed_out? #=> true
```

#### ProcessExecuter.run

Has the functionality of `ProcessExecuter.spawn_with_timeout` plus:

1. Allows any object that implements `#write` (e.g. a StirngIO) to be given as a
    stdout or stderr redirection destination
2. An errors is raised for any problem running the command which can be turned off
    with the `raise_errors: <Boolean>` option (default is `true`)
3. Logs the command and its result to a logger (at :info level) optionally given in
    the `logger: <logger>` option (default is no logging)

⚠️ `ProcessIOError` and `SpawnError` errors are not suppressed by giving the `raise_errors: false`

Example of capturing stdout using a StringIO:

```ruby
stdout_buffer = StringIO.new
result = ProcessExecuter.run('echo "Hello World"', out: string_buffer)
stdout_buffer.string #=> "Hello World\n"
```

#### ProcessExecuter.run_with_capture

Has the functionality of `ProcessExecuter.run` plus:

1. stdout and stderr are automatically captured
2. Can be told to merge stdout and stderr output using the `merge_output: <Boolean>`
    option (default is `false`)
3. Returns a `ProcessExecuter::ResultWithCapture` which has the same attributes as a
    `ProcessExecuter::Result` plus captured `stdout` and `stderr`

Example of capturing stdout and stderr:

```ruby
result = ProcessExecuter.run_with_capture("echo Hello; echo ERROR>&2")
result.stdout #=> "Hello\n"
result.stderr #=> "ERROR\n"
```

Merged stdout and stderr is available in the result objects stdout attribute:

```ruby
result = ProcessExecuter.run_with_capture("echo Hello; echo ERROR>&2", merged_output: true)
result.stdout #=> "Hello\nERROR\n"
result.stderr #=> ""
```

### Key Classes

#### ProcessExecuter::MonitoredPipe

`ProcessExecuter::MonitoredPipe` objects can be used as a redirection destination for
`Process.spawn` (or any of the derivitive methods in the `ProcessExecuter` module) to
stream output from a subprocess to one or more destinations. Destinations are given
in this class's initializer.

The destinations are all the redirection destinations allowed by `Process.spawn` (see
[the File Redirection
secion](https://docs.ruby-lang.org/en/3.4/Process.html#module-Process-label-File+Redirection+-28File+Descriptor-29)
in the Process module documentation) plus the following:

- Any object with a #write method even if it does not have a file descriptor (like
  instances of StringIO)
- An array of destinations can be given in the form `[:tee, <obj>...]`

Example of capturing stdout to a StringIO (which is not directly possible with
`Process.spawn`):

```ruby
require 'stringio'
require 'process_executer'

output_buffer = StringIO.new
out_pipe = ProcessExecuter::MonitoredPipe.new(output_buffer)
begin
  pid, status = Process.wait2(Process.spawn('echo "Hello World"', out: out_pipe))
ensure
  out_pipe.close # Close the pipe so all the data is flushed and resources are not leaked
end
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
begin
  pid, status = Process.wait2(Process.spawn('echo "Hello World"', out: out_pipe))
ensure
  out_pipe.close
end
output_file.close
output_buffer.string #=> "Hello World\n"
File.read('process.out') #=> "Hello World\n"
```

## Breaking Changes

### 2.x

This major release focused on changes to the interface to make it more understandable.

#### `ProcessExecuter.spawn`

- This method was renamed to `ProcessExecuter.spawn_with_timeout`
- The `:timeout` option was renamed to `:timeout_after`

#### `ProcessExecuter.run`

- The `:timeout` option was renamed to `:timeout_after`

#### `ProcessExecuter::Result`

- The `#timeout` method was renamed to `#timed_out`

#### Other

- Dropped support for Ruby 3.0

### 3.x

#### `ProcessExecuter.run`

- The `:merge` option was removed

  This was removed because `Process.spawn` already provides this functionality but in
  a different way. To merge, you will need to define a redirection where the source
  is an array of the file descriptors you want to merge. For instance:

  ```Ruby
  [:out, :err] => 'output.txt'
  ```

  will merge stdout and stderr from the subprocess into the file output.txt.

- Stdout and stderr redirections are no longer default to a new instance of StringIO

  Calls to `ProcessExecuter.run` that do not define a redirection for stdout or
  stderr will have to add explicit redirection(s) in order to capture the output.

  This is to align with the functionality in `Process.spawn`. In `Process.spawn`, when
  an explicit redirection is not given for stdout and stderr, this output will be
  passed through to the parent process's stdout and stderr.

### 4.x

#### `ProcessExecuter.spawn_and_wait`

`ProcessExecuter.spawn_and_wait` has been renamed to `ProcessExecuter.spawn_with_timeout`.

#### `ProcessExecuter::Result`

`Result#stdout` and `Result#stderr` were removed. Users depending on these methods
will either have to capture this output themselves or change from using
`.spawn_and_wait`/`.run` to `.run_with_capture` which returns a `ResultWithCapture`
object.

#### `ProcessExecuter.spawn_and_wait_with_options`

`ProcessExecuter.spawn_and_wait_with_options` has been removed. Instead call
`ProcessExecuter.spawn_with_timeout` which is overloaded to take the same method
arguments.

#### `ProcessExecuter.run_with_options`

`ProcessExecuter.run_with_options` has been removed. Instead call
`ProcessExecuter.run` which is overloaded to take the same method arguments.

#### Other

In places where users of this gem rescued `::ArgumentError`, they will have to change
the rescued class to `ProcessExecuter::ArgumentError`.

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

- A git commit-msg hook that validates your commit messages before they are accepted.

  To activate the hook, you must have node installed and run `npm install`.

- A GitHub Actions workflow that will enforce the Conventional Commit standard as
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
