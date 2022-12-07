# Changelog

All notable changes to the process_executer gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.4.0 (2022-12-06)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.3.0...v0.4.0)

* 9ac17a4 Remove build using jruby-head on windows
* d36d131 Work around a SimpleCov problem when using JRuby
* b6b3a19 Remove unused Status and Process classes
* a5cdf04 Allow 100% coverage check to be skipped
* a3fa1f5 Output coverage details when coverage is below 100%
* 6a9a417 Refactor monitor so that closing the pipe is on the monitoring thread
* 65ee9a2 Add JRuby and Windows builds
* 2e713e3 Release v0.3.0

## v0.3.0 (2022-12-01)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.2.0...v0.3.0)

* 6e2cdf1 Completely refactor to a single ProcessExecuter.spawn method (#7)
* 6da57ec Add CodeClimate badges to README.md (#6)
* eebd6ae Add front matter and v0.1.0 release to changelog (#5)
* 78cb9e5 Release v0.2.0

## v0.2.0 (2022-11-16)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.1.0...v0.2.0)

* 8b70ac0 Use the create_github_release gem to make the release PR (#2)
* 4b2700e Add ProcessExecuter#execute to execute a command and return the result (#1)

## v0.1.0 (2022-10-20)

Initial release of an empty project
