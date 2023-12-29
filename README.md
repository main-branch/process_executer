# The ProcessExecuter Gem

[![Gem Version](https://badge.fury.io/rb/process_executer.svg)](https://badge.fury.io/rb/process_executer)
[![Documentation](https://img.shields.io/badge/Documentation-Latest-green)](https://rubydoc.info/gems/process_executer/)
[![Change Log](https://img.shields.io/badge/CHANGELOG-Latest-green)](https://rubydoc.info/gems/process_executer/file/CHANGELOG.md)
[![Build Status](https://github.com/main-branch/process_executer/workflows/CI%20Build/badge.svg?branch=main)](https://github.com/main-branch/process_executer/actions?query=workflow%3ACI%20Build)
[![Maintainability](https://api.codeclimate.com/v1/badges/0b5c67e5c2a773009cd0/maintainability)](https://codeclimate.com/github/main-branch/process_executer/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/0b5c67e5c2a773009cd0/test_coverage)](https://codeclimate.com/github/main-branch/process_executer/test_coverage)

* [Features](#features)
  * [ProcessExecuter::MonitoredPipe](#processexecutermonitoredpipe)
  * [ProcessExecuter.spawn](#processexecuterspawn)
* [Installation](#installation)
* [Usage](#usage)
* [Development](#development)
* [Releasing](#releasing)
* [Determine Semver increment](#determine-semver-increment)
* [Contributing](#contributing)
* [License](#license)

## Features

[Full YARD documentation](https://rubydoc.info/gems/process_executer/) for this
gem is hosted on RubyGems.org.

This gem contains the following important classes:

### ProcessExecuter::MonitoredPipe

`ProcessExecuter::MonitoredPipe` streams data sent through a pipe to one or more writers.

When a new `MonitoredPipe` is created, an pipe is created (via IO.pipe) and
a thread is created which reads data as it is written written to the pipe.

Data that is read from the pipe is written one or more writers passed to
`MonitoredPipe#initialize`.

This is useful for streaming process output (stdout and/or stderr) to anything that has a
`#write` method: a string buffer, a file, or stdout/stderr as seen in the following example:

```ruby
require 'stringio'
require 'process_executer'

output_buffer = StringIO.new
out_pipe = ProcessExecuter::MonitoredPipe.new(output_buffer)
pid, status = Process.wait2(Process.spawn('echo "Hello World"', out: out_pipe))
output_buffer.string #=> "Hello World\n"
```

`MonitoredPipe#initialize` can take more than one writer so that pipe output can be
streamed (or `tee`d) to multiple writers at the same time:

```ruby
require 'stringio'
require 'process_executer'

output_buffer = StringIO.new
output_file = File.open('process.out', 'w')
out_pipe = ProcessExecuter::MonitoredPipe.new(output_buffer, output_file)
pid, status = Process.wait2(Process.spawn('echo "Hello World"', out: out_pipe))
output_file.close
output_buffer.string #=> "Hello World\n"
File.read('process.out') #=> "Hello World\n"
```

Since the data is streamed, any object that implements `#write` can be used. For insance,
you can use it to parse process output as a stream which might be useful for long XML
or JSON output.

### ProcessExecuter.spawn

`ProcessExecuter.spawn` has the same interface as `Process.spawn` but has two
important behaviorial differences:

1. It blocks until the subprocess finishes
2. A timeout can be specified using the `:timeout` option

If the command does not terminate before the timeout, the process is killed by
sending it the SIGKILL signal.

## Installation

Install the gem and add to the application's Gemfile by executing:

```shell
bundle add process_executer
```

If bundler is not being used to manage dependencies, install the gem by executing:

```shell
gem install process_executer
```

## Usage

See the examples in the project's YARD documentation.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Releasing

To release a new version, first determine the proper semver increment based on the
type of changes made in the release as described in [Determine Semver
increment](#determine-semver-increment).

In the root directory of the project with the `main` branch checked out, run the
following command:

```shell
create-github-release {major|minor|patch}`
```

Follow the directions given by the `create-github-release` to publish the new version
of the gem.

## Determine Semver increment

When creating a new release, determine the semver increment according to the following
rules.

* `major`: When making incompatible API changes, increment the MAJOR version.

  This typically occurs when the changes introduced would break existing code that
  depends on this gem. For example, removing a public method, changing a method's
  signature, or altering the expected behavior of a method in a way that would
  require changes in the dependent code.

* `minor`: When adding functionality in a backward-compatible manner, increment the
  MINOR version.

  This includes adding new features, enhancements, or deprecating existing features
  (as long as the deprecation itself doesn't break compatibility).

  It's also common to include substantial improvements or optimizations in this
  category, as long as they don't alter the expected behavior of the existing API.

* `patch`: When making backward-compatible bug fixes, increment the PATCH version.

  This is for small changes that fix issues without adding new functionality or
  altering existing functionality (beyond the scope of fixing a bug).

  It can also include internal changes that don't affect the API, like refactoring
  code, improving performance, or updating documentation.

## Contributing

Bug reports and pull requests are welcome on our
[GitHub issue tracker](https://github.com/main-branch/process_executer)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
