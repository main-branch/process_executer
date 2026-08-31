# Changelog

All notable changes to the process_executer gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.1.0](https://github.com/main-branch/process_executer/compare/v4.1.0...v4.1.0) (2026-08-31)


### Other Changes

* Characterize validation ordering when unknown and invalid options are given together ([#192](https://github.com/main-branch/process_executer/issues/192)) ([15d6e06](https://github.com/main-branch/process_executer/commit/15d6e063170484f309efd30867238b867484288b))
* Collapse encoding validators and clarify capture-redirection assembly ([#194](https://github.com/main-branch/process_executer/issues/194)) ([bab8610](https://github.com/main-branch/process_executer/commit/bab86101ac4cdbd3747e72d0d7f841623a6e9b20))
* Contribute subclass redirections via an internal_redirections hook ([#190](https://github.com/main-branch/process_executer/issues/190)) ([8ecbda5](https://github.com/main-branch/process_executer/commit/8ecbda54874de933ab07a64d91e0a07e17f7ece0))
* Derive the process-group isolation decision from a single source ([#191](https://github.com/main-branch/process_executer/issues/191)) ([5d8ac7d](https://github.com/main-branch/process_executer/commit/5d8ac7dc38a369a7fe6d6cf3d05bd1eec799f3dc))
* Describe every source of MonitoredPipe#exception ([#193](https://github.com/main-branch/process_executer/issues/193)) ([333b7bd](https://github.com/main-branch/process_executer/commit/333b7bd4c552c246d7d7505b5aa3e1a123ac5f9b))
* Extract shared validate! from Options::Base#initialize and #merge! ([#192](https://github.com/main-branch/process_executer/issues/192)) ([422956a](https://github.com/main-branch/process_executer/commit/422956acaab46e29ecc1373d017d719ea6eb497f))
* Track opened pipes as per-call instance state instead of an out-parameter ([#190](https://github.com/main-branch/process_executer/issues/190)) ([f279f1e](https://github.com/main-branch/process_executer/commit/f279f1e0672b91b966ee73cbadf00749522e488d))

## [4.1.0](https://github.com/main-branch/process_executer/compare/v4.0.4...v4.1.0) (2026-08-30)


### Bug Fixes

* Make timeout_after bound execution even when descendants hold stdout/stderr open ([a1298d3](https://github.com/main-branch/process_executer/commit/a1298d3f98fd8e57f58f50a0566dd3be78079189))
* **monitored_pipe:** Close acquired resources when #initialize fails partway ([8f10a86](https://github.com/main-branch/process_executer/commit/8f10a86b42c4d72f0f34004071cfeb91116d6bd4)), closes [#178](https://github.com/main-branch/process_executer/issues/178)
* **monitored_pipe:** Do not hold the mutex while writing to the pipe ([91d7fe8](https://github.com/main-branch/process_executer/commit/91d7fe88b9950d24f8c28ccbea400be0063ec99a)), closes [#165](https://github.com/main-branch/process_executer/issues/165)
* **monitored_pipe:** Handle a destination raising a non-StandardError ([a7de23b](https://github.com/main-branch/process_executer/commit/a7de23b5699ef4d32518e988ac76dd6a957277e3)), closes [#170](https://github.com/main-branch/process_executer/issues/170)
* Replace the monitor thread's 1ms poll with an event-driven wakeup pipe ([44068a3](https://github.com/main-branch/process_executer/commit/44068a35f4f87de9b7b46ce1deffda636f7c1138))
* Return a timed out result when the timeout races Process.wait2 reaping the child ([84a6a11](https://github.com/main-branch/process_executer/commit/84a6a11df7d736f26d98700e90a76f5d65e2d35c)), closes [#171](https://github.com/main-branch/process_executer/issues/171)
* **run_with_capture:** Capture combined [:out, :err] redirection into stdout ([17199b8](https://github.com/main-branch/process_executer/commit/17199b8ea332278680c46accce072763f0d67a4a)), closes [#167](https://github.com/main-branch/process_executer/issues/167)
* **run:** Close created pipes and keep the original error when pipe creation fails ([909eaa1](https://github.com/main-branch/process_executer/commit/909eaa177fa53ee4cd4e773595a8658ea94ca6a4)), closes [#166](https://github.com/main-branch/process_executer/issues/166)
* **run:** Stop mutating caller options and closing caller-owned pipes ([96d922b](https://github.com/main-branch/process_executer/commit/96d922b4bff5586189b30d9a1f83b0d47159710f)), closes [#169](https://github.com/main-branch/process_executer/issues/169)
* Validate options merged via Options::Base#merge! ([#173](https://github.com/main-branch/process_executer/issues/173)) ([da0a956](https://github.com/main-branch/process_executer/commit/da0a956bcb085378b1315dafb87351174500c966))


### Other Changes

* Add failing tests for merge! bypassing option validation ([#173](https://github.com/main-branch/process_executer/issues/173)) ([325f16e](https://github.com/main-branch/process_executer/commit/325f16e589821571f3250e86a82f51f0e6b70f9a))
* Add failing tests for the monitor thread 1ms polling loop ([#172](https://github.com/main-branch/process_executer/issues/172)) ([e202909](https://github.com/main-branch/process_executer/commit/e202909f99074a8ceb331f13290c224c35904e7a))
* Add failing tests for the timeout vs Process.wait2 reap race ([#171](https://github.com/main-branch/process_executer/issues/171)) ([647739a](https://github.com/main-branch/process_executer/commit/647739ad7233059aafb54dad70eef14998892c5d))
* Add failing tests for timeout_after not bounding execution ([#164](https://github.com/main-branch/process_executer/issues/164)) ([8e5115c](https://github.com/main-branch/process_executer/commit/8e5115c9236347e77ba6e6d0631f5f1bfe826b26))
* **coverage:** Only enforce code coverage on MRI builds not on Windows ([160815e](https://github.com/main-branch/process_executer/commit/160815ecb091d1f155406f9a1b37f73e13690627))
* Enforce LF line endings on all platforms ([e94bfea](https://github.com/main-branch/process_executer/commit/e94bfeaf4bd93506090277b4020859cd23dfc625))
* Explain stdin redirection via the in: option ([f7bded7](https://github.com/main-branch/process_executer/commit/f7bded743a204a99c7f6e272b0330d4ba1e4a037)), closes [#159](https://github.com/main-branch/process_executer/issues/159)
* **monitored_pipe:** Accept the documented IOError and confine failures ([002274d](https://github.com/main-branch/process_executer/commit/002274d421afc84c7c441c6f56dbbc32506e1de2)), closes [#182](https://github.com/main-branch/process_executer/issues/182)
* **monitored_pipe:** Add a failing test for the #write deadlock ([9826558](https://github.com/main-branch/process_executer/commit/9826558035b03fe7becdc729053519141ba8d00d))
* **monitored_pipe:** Add failing tests for a destination raising a non-StandardError ([0177329](https://github.com/main-branch/process_executer/commit/0177329fb47f3c185d9ea768f9f80028c54fb7ab))
* **monitored_pipe:** Add failing tests for resource leaks when #initialize fails ([b2e3151](https://github.com/main-branch/process_executer/commit/b2e31519ea7a38f774b90f6e9e1f17fa0b31baa3)), closes [#178](https://github.com/main-branch/process_executer/issues/178)
* **monitored_pipe:** Make the writer-exception race deterministic ([c72f1e4](https://github.com/main-branch/process_executer/commit/c72f1e400ef3d78e4b092ecde0d0704cf79ebc36)), closes [#182](https://github.com/main-branch/process_executer/issues/182)
* **monitored_pipe:** Stub the monitor loop on the class, not the live instance ([799177f](https://github.com/main-branch/process_executer/commit/799177f6046d661013ce6b68b19c6b220294d00f))
* **process-spawn:** Check exit status and blocking, and add a subspawn backend ([99021d2](https://github.com/main-branch/process_executer/commit/99021d2144a21210f793b7ae94d36875eef504e6))
* **process-spawn:** Run the spawn tests against the subspawn backend ([573086f](https://github.com/main-branch/process_executer/commit/573086f194e790f25d916de32bb5e94437a5ae86))
* **rake:** Skip RuboCop in the default task on TruffleRuby ([3d2a118](https://github.com/main-branch/process_executer/commit/3d2a1186d65e76f170f5428d611822d95d8fdc2d))
* Release the hardening changes as v4.1.0 instead of v4.0.5 ([70b6327](https://github.com/main-branch/process_executer/commit/70b63278f334bd8b714c2fc28ded1520921add09))
* **run_with_capture:** Add failing tests for combined [:out, :err] redirection ([61e97cb](https://github.com/main-branch/process_executer/commit/61e97cb09c816cbe30d81dc33f268accf76ab396))
* **run:** Add failing tests for options mutation and caller-owned pipe closing ([cf32615](https://github.com/main-branch/process_executer/commit/cf326156381fe81562597906d43134a08ebbef17))
* **run:** Add failing tests for pipe creation failure in Run#call ([21521d9](https://github.com/main-branch/process_executer/commit/21521d9a9b5141d9bb6d22fb5fd3e7de0e497ca2))
* **run:** Update the JRuby expectation for an invalid chdir path ([2712f0b](https://github.com/main-branch/process_executer/commit/2712f0bdf060fa1831edb428183283dec5f2727a))
* Use RbConfig.ruby to locate the Ruby interpreter ([82e65e2](https://github.com/main-branch/process_executer/commit/82e65e202a4f884a3283b4af00fcd2b5eda3a394))

## [4.0.4](https://github.com/main-branch/process_executer/compare/v4.0.3...v4.0.4) (2026-04-24)


### Bug Fixes

* **rubocop:** Fix offenses introduced by new rubocop cops ([b21ca99](https://github.com/main-branch/process_executer/commit/b21ca991641784146b0c92c1dd3205fc9d2c0f4f))


### Other Changes

* **dependencies:** Update dependencies for all GitHub Actions workflows ([3524dbf](https://github.com/main-branch/process_executer/commit/3524dbf8b5945c233be96381f4555407b537f236))

## [4.0.3](https://github.com/main-branch/process_executer/compare/v4.0.2...v4.0.3) (2026-01-04)


### Other Changes

* Note JRuby Windows support issue ([4cc6903](https://github.com/main-branch/process_executer/commit/4cc69036bbdda383a8ecb50bd63b19f96303203a))

## [4.0.2](https://github.com/main-branch/process_executer/compare/v4.0.1...v4.0.2) (2026-01-03)


### Other Changes

* Bump actions/checkout@v5 and actions/setup-java@v5 ([07c6488](https://github.com/main-branch/process_executer/commit/07c6488b21305cbffb059c181e7720868781ddd4))
* Fix process spawn workflow link ([316fdeb](https://github.com/main-branch/process_executer/commit/316fdebce530b2be5ceb5046e21ee848af52381a))
* Run process-spawn specs under bash on Windows ([320ceb0](https://github.com/main-branch/process_executer/commit/320ceb0395c85bb40b1706efb0c6e71f50a20d06))
* Run process-spawn tests from subdirectory ([ef8b968](https://github.com/main-branch/process_executer/commit/ef8b968b0cc8ff6b8d1ea051ff5836fcaf65ff7e))
* Update Ruby version support policy ([0df371d](https://github.com/main-branch/process_executer/commit/0df371d004da62ed3bcb6685aba53d62d7061d02))

## [4.0.1](https://github.com/main-branch/process_executer/compare/v4.0.0...v4.0.1) (2025-12-29)


### Other Changes

* Add Copilot instructions for process_executer gem ([d567df2](https://github.com/main-branch/process_executer/commit/d567df2020b655493adebfcbf55a83a61d944c2f))
* Add irb as development dependency ([95443c0](https://github.com/main-branch/process_executer/commit/95443c0fc2ef9a7aa8ff982811622d761fe09db9))
* Add Ruby 4.0 to continuous integration test matrix ([5f032b4](https://github.com/main-branch/process_executer/commit/5f032b46ee67474b871484d20105b044207b62f2))

## [4.0.0](https://github.com/main-branch/process_executer/compare/v3.2.4...v4.0.0) (2025-06-05)


### ⚠ BREAKING CHANGES

* Users who call ProcessExecuter::Options::Base#with even if from a derived class will need to update to use #merge instead.
* Users depending on `Result#stdout` or `Result#stderr` will either have to capture this output manually themselves or change from `spawn_and_wait`/`run` to `run_with_capture`.
* calls to `ProcessExecuter.spawn_with_timeout_with_options` and `ProcessExecuter.run_with_options` have been removed. Use `ProcessExecuter.spawn_with_timeout` and `ProcessExecuter.run` instead.
* Users who use ProcessExecuter.spawn_and_wait will need to update their calls to spawn_with_timeout. In addition, the following items will need to be updated if used by the user of this gem:
    * ProcessExecuter.spawn_and_wait_with_options
    * ProcessExecuter::SpawnAndWaitOptions
* In places where users of this gem rescued ::ArgumentError, they will have to change the rescued class to ProcessExecuter::ArgumentError.

### Features

* Add `ProcessExecuter.run_with_capture` ([d9e97fe](https://github.com/main-branch/process_executer/commit/d9e97fe7728a0c7fce9520ad5ba9568782243f70))
* Add encoding, stdout_encoding, stderr_encoding options to RunWithCaptureOptions ([83eaa93](https://github.com/main-branch/process_executer/commit/83eaa93417e810c1a1b569616c19d8facdc2b2f4))
* Add ProcessExecuter::ArgumentError and raise it instead of ::ArgumentError ([860fc5a](https://github.com/main-branch/process_executer/commit/860fc5a224f86dd4ff525de32b643fc261e456f6))
* Ensure that all data written by MonitoredPipe is ASCII-8BIT encoded ([8753006](https://github.com/main-branch/process_executer/commit/87530066280ed91afc208714514df845e4455b6b))
* Make run_with_capture encode captured stdout and stderr based on encoding options ([75c3d92](https://github.com/main-branch/process_executer/commit/75c3d922fa74a17b61b415fe50acd9763a00524f))
* Remove #spawn_with_timeout_with_options and #run_with_options methods ([446cb51](https://github.com/main-branch/process_executer/commit/446cb510a634ff5171df6b0fcb2d426cb3f9ed9e))
* Remove Result#stdout and Result#stderr ([2dcad47](https://github.com/main-branch/process_executer/commit/2dcad47bb921170070f8d4bae1ce07244547db5c))
* Rename ProcessExecuter::Options::Base#with to #merge ([7e8c28e](https://github.com/main-branch/process_executer/commit/7e8c28e33b99945187d272766134e30b5746ddc8))
* Rename ProcessExecuter.spawn_and_wait to spawn_with_timeout ([b9d19e7](https://github.com/main-branch/process_executer/commit/b9d19e792234996f78c7cd63b22047bb7474a06d))


### Bug Fixes

* Fix new rubocop offense Style/EmptyStringInsideInterpolation ([bb610af](https://github.com/main-branch/process_executer/commit/bb610af96519cccd2fe1be62e61b1531711e5d9b))


### Other Changes

* Add a JRuby 10 build to the continuous integration workflow ([7a939ba](https://github.com/main-branch/process_executer/commit/7a939ba5bf7b291555a4259db7040b6cb96f494b))
* Document the new encoding options on ProcessExecuter.run_with_capture ([c86ce62](https://github.com/main-branch/process_executer/commit/c86ce627b8c081981a92414c35eafb85b99e3201))
* Ensure that binary data is correctly written to file destinations ([0d2db54](https://github.com/main-branch/process_executer/commit/0d2db54d2b9c4354cb880a17a6b683dc8b5f8424))
* Fix indentation in README ([1837e7a](https://github.com/main-branch/process_executer/commit/1837e7a5cee56ccc7f3ebdc7f71aab43d1a56ab4))
* Internally refactor classes for clarity and update documentation ([da1db96](https://github.com/main-branch/process_executer/commit/da1db9697e5c2be371d308d5790e44dcccf8e40b))
* Remove unneeded :nocov: blocks ([7a1fcf5](https://github.com/main-branch/process_executer/commit/7a1fcf500b89d7fe8e7254ba4fa20e38f0b46d45))
* Update the README with all the changes for the latest release ([38206a5](https://github.com/main-branch/process_executer/commit/38206a57d26dcca3437611291ab3ccdc1d5a442f))

## [3.2.4](https://github.com/main-branch/process_executer/compare/v3.2.3...v3.2.4) (2025-04-18)


### Other Changes

* Configure release-please to includes all changes in the CHANGELOG ([41acdbc](https://github.com/main-branch/process_executer/commit/41acdbcee8bc6e7ebef5e45356bb9197b652a498))
* Do not enforce conventional commits for release PR ([080f3ff](https://github.com/main-branch/process_executer/commit/080f3ff0b131bb4c91f5798bb6e57fe964091f8c))

## [3.2.3](https://github.com/main-branch/process_executer/compare/v3.2.2...v3.2.3) (2025-04-17)


### Bug Fixes

* Do not trigger build workflows after merging to main or for release PRs ([0b2701c](https://github.com/main-branch/process_executer/commit/0b2701c4eef8ecc929f9f987433599145b224256))

## [3.2.2](https://github.com/main-branch/process_executer/compare/v3.2.1...v3.2.2) (2025-04-16)


### Bug Fixes

* Automate commit-to-publish workflow ([c51e8d2](https://github.com/main-branch/process_executer/commit/c51e8d2dfcff21ccd634fe58d5eb3b733869877d))

## v3.2.1 (2025-04-08)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v3.2.0..v3.2.1)

Changes since v3.2.0:

* d1e19a5 test: assert that MonitoredPipe has no open instances after each test
* aa71f8e test: ensure MonitoredPipe cleans up open instances in specs
* 987b0c9 fix: ensure that all pipes are closed even when there is an IOError
* 65e8db0 fix: ensure that MonitoredPipe cleans up after itself even when there is IOError
* ed2454e chore: integrate track_open_instances gem to report on leaked MonitoredPipe instances
* f25c87d chore: release v3.2.0

## v3.2.0 (2025-04-04)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v3.1.0..v3.2.0)

Changes since v3.1.0:

* 272d246 test: fix flaky test that fails on windows
* 1e121d8 test: add test for raising a SpawnError when Process.spawn raises an error
* 2a2aaac refactor: improve synchronization of the monitored pipe state

## v3.1.0 (2025-04-01)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v3.0.0..v3.1.0)

Changes since v3.0.0:

* acb6385 fix: give Windows enough time to release its file lock so tmpdir can be deleted
* 3fe114a feat: wrap errors raised by `Process.spawn` in a `ProcessExecuter::SpawnError`

## v3.0.0 (2025-03-18)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v2.0.0..v3.0.0)

Changes since v2.0.0:

* 3d337de feat: remove Options setter methods and add `with` method
* 706d78a docs: add a list the breaking changes for each major release in the README.md
* 2903c80 feat: report all option errors instead of just the first one
* 247150d feat!: do not capture stdout and stderr by default in `ProcessExecuter.run`
* 4b3ac02 feat: support redirection destinations in the form [:child, fd] and :close
* ed4620f docs: update README.md to highlight the important parts of this gem
* 48b4695 fix: allow Integer or IO are used as a redirection source
* 4424a44 feat!: remove the :merge option from ProcessExecuter.run
* 7257e5d chore: allow SpawnOptions to accept Integer and IO redirection sources
* 92441d0 chore: move all options related classes to a new Options module
* 92c096c chore: remove unneeded test file
* 91d0db3 feat: implement all possible redirection destinations
* a58af4a fix: fix complexity error reported by CodeClimate
* 66d97b7 chore: do not fail the CI build for low coverage on JRuby and TruffleRuby
* 2fb0ccf feat: refactor options classes
* bcf35d5 chore: do not fail the CI build for low coverage on JRuby and TruffleRuby

## v2.0.0 (2025-03-03)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v1.3.0..v2.0.0)

Changes since v1.3.0:

* f0836cc feat: refactor the interface to simplify the gem

## v1.3.0 (2025-02-26)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v1.2.0..v1.3.0)

Changes since v1.2.0:

* d1e189b build: add Ruby 3.4 to the CI workflow
* e805dfc feat: implement ProcessExecuter.run_command
* bad822f fix: update the yard build in the rake file and update included files
* 6fbdc5e feat: allow #spawn to accept file descriptors for redirection destination
* d745685 test: make it so that tests do not give unnecessary output

## v1.2.0 (2024-10-10)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v1.1.2..v1.2.0)

Changes since v1.1.2:

* 35663c9 chore: reset main branch to 1.x
* 39913bc build: remove semver pr label check
* 8ae8e34 build: enforce conventional commit message formatting
* f5b8c51 Release v2.0.0.pre1
* 8e15c39 Re-add require for 'forwardable'
* 4bba06e Fix flakey test that checks for thread to die
* 83bfd78 Remove unused require for 'forwardable' and 'ostruct'
* ea3ea3c Use shared Rubocop config
* ecd2cb5 Update copyright notice in this project
* 7d5bfe1 Update links in gemspec
* 797de91 Add Slack badge for this project in README
* 591b716 Update “Build Status” link the README
* 2fcd001 Update yardopts with new standard options
* 4e1de47 Standardize YARD and Markdown Lint configurations
* 929c680 Set JRuby --debug option when running tests in GitHub Actions workflows
* 71049cb Finish Integration of simplecov-rspec into the project
* 4fb44bb Update continuous integration and experimental ruby builds
* 289645c Depend on v1 of semver_pr_label_check
* 3c4d988 Update code climate test coverage reporter version
* 04103b4 Simplify how the experimental ruby builds are triggered
* 35840a4 Use a reusable workflow for the Semver PR label check
* 0d887f0 Update code climate test coverage reporter version
* bb7f73b Rename the experimental build workflow
* 035ce8a Fix the experimental CI Build workflow
* 3d739f4 Move CI builds using experimental Rubies to a different workflow
* c5ef6b0 Integrate simplecov-rspec to ensure code covage in CI builds
* f33707e Update development dependencies and examples (#45)

## v2.0.0.pre1 (2024-09-26)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v1.1.0..v2.0.0.pre1)

Changes since v1.1.0:

* 8e15c39 Re-add require for 'forwardable'
* 4bba06e Fix flakey test that checks for thread to die
* 83bfd78 Remove unused require for 'forwardable' and 'ostruct'
* ea3ea3c Use shared Rubocop config
* ecd2cb5 Update copyright notice in this project
* 7d5bfe1 Update links in gemspec
* 797de91 Add Slack badge for this project in README
* 591b716 Update “Build Status” link the README
* 2fcd001 Update yardopts with new standard options
* 4e1de47 Standardize YARD and Markdown Lint configurations
* 929c680 Set JRuby --debug option when running tests in GitHub Actions workflows
* 71049cb Finish Integration of simplecov-rspec into the project
* 4fb44bb Update continuous integration and experimental ruby builds
* 289645c Depend on v1 of semver_pr_label_check
* 3c4d988 Update code climate test coverage reporter version
* 04103b4 Simplify how the experimental ruby builds are triggered
* 35840a4 Use a reusable workflow for the Semver PR label check
* 0d887f0 Update code climate test coverage reporter version
* bb7f73b Rename the experimental build workflow
* 035ce8a Fix the experimental CI Build workflow
* 3d739f4 Move CI builds using experimental Rubies to a different workflow
* c5ef6b0 Integrate simplecov-rspec to ensure code covage in CI builds
* f33707e Update development dependencies and examples (#45)

## v1.1.0 (2024-02-02)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v1.0.2..v1.1.0)

Changes since v1.0.2:

* a473281 ProcessExecuter.spawn should indicate if the subprocess timed out or not (#43)

## v1.0.2 (2024-02-01)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v1.0.1..v1.0.2)

Changes since v1.0.1:

* 76ffb91 An invalid timeout value should raise an ArgumentError (#41)
* b748819 Release v1.0.1 (#40)

## v1.0.1 (2024-01-04)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v1.0.0..v1.0.1)

Changes since v1.0.0:

* f434aa1 Add an experimental build for jruby-head on windows (#15)
* 97dbcf5 Make updates resulting from doc review (#38)
* 93eab18 Release v1.0.0 (#37)

## v1.0.0 (2023-12-31)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.7.0..v1.0.0)

Changes since v0.7.0:

* e11f03e Separate semver PR label check into its own workflow (#36)
* eabcc3e Update min req Ruby version from 2.7 to 3.0 (#32)
* 5483bb8 Update spec_helper.rb to new standard (#31)
* 4a27341 Update all development dependencies to latest versions (#30)
* ea7513d Enforce that a semver label is present on PRs (#28)
* 0aa26cd Instruct Rubocop that dev deps go in gemspec (#29)
* 53cb526 Add a truffle-ruby build on ubuntu (#18)

## v0.7.0 (2023-02-17)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.6.1..v0.7.0)

Changes since v0.6.1:

* c5c07fd Reduce the time spent waiting for output (#25)

## v0.6.1 (2023-02-12)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.6.0..v0.6.1)

Changes since v0.6.0:

* 34b28a0 Documentation cleanup (#23)

## v0.6.0 (2023-02-12)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.5.0..v0.6.0)

Changes since v0.5.0:

* 2a22dbd Fix intermittent test failures (#21)
* e3afaa3 Add build for MRI Ruby 3.2 on unbuntu-latest (#20)
* 17522ac Use latest create_release_version gem (#19)
* ba1fb2d Read remaining data from pipe_reader when closing a MonitoredPipe (#17)
* 8422aa9 Release v0.5.0

## v0.5.0 (2022-12-12)

[Full Changelog](https://github.com/main-branch/process_executer/compare/v0.4.0...v0.5.0)

* c6d8de9 Workaround a problem with SimpleCov / JRuby
* c480b5f Increase time to wait for results from a writer throwing an exception
* 1934563 Handle exceptions from writers within MonitoredPipe
* e948ada Increase default chunk_size to 100_000 bytes
* 5eb2c24 Update documentation for ProcessExecuter#spawn
* a3a4217 Release v0.4.0

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
