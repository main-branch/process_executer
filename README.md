# The ProcessExecuter Gem

An API for executing commands in a subprocess

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

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push git
commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on our
[GitHub issue tracker](https://github.com/main-branch/process_executer)

## Feature Checklist

Here is the 1.0 feature checklist:

* [x] Run a command
* [x] Collect the command's stdout/stderr to a string
* [x] Passthru the command's stdout/stderr to this process's stdout/stderr
* [ ] Command execution timeout
* [ ] Redirect stdout/stderr to a named file
* [ ] Redirect stdout/stderr to a named file with open mode
* [ ] Redirect stdout/stderr to a named file with open mode and permissions
* [ ] Redirect stdout/stderr to an open File object
* [ ] Merge stdout & stderr
* [ ] Redirect a file to stdin
* [ ] Redirect from a butter to stdin
* [ ] Binary vs. text mode for stdin/stdout/stderr
* [ ] Environment isolation like Process.spawn
* [ ] Pass options to Process.spawn (chdir, umask, pgroup, etc.)
* [ ] Don't allow optionis to Process.spawn that would break the functionality
    (:in, :out, :err, integer, #fileno, :close_others)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
