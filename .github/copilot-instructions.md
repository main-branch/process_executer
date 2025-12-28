# GitHub Copilot Instructions for ProcessExecuter

## Project Overview

ProcessExecuter is a Ruby gem that provides an enhanced API for executing commands in
subprocesses, extending Ruby's built-in `Process.spawn` functionality.

It provides additional features like:
- Capturing output (stdout and stderr)
- Handling timeouts by terminating processes with SIGKILL
- Streaming output to multiple destinations simultaneously
- Detailed result information including elapsed time and timeout status

**Current Status:** Stable project supporting Ruby 3.1.0+ minimum. Compatible with
MRI 3.1+, TruffleRuby 24+, and JRuby 9.4+ on Mac, Linux, and Windows.

## Architecture & Module Organization

ProcessExecuter follows a modular architecture:

- **Core Methods** - `spawn_with_timeout`, `run`, and `run_with_capture` extend
  `Process.spawn`
- **Result Classes** - Decorators for `Process::Status` with additional metadata
- **Options Classes** - Type-safe option handling for method arguments
- **MonitoredPipe** - Enables streaming output to multiple destinations
  simultaneously
- **Destinations** - Output targets (IO, String, Logger, etc.)
- **Commands** - Command abstraction and validation
- **Errors** - Comprehensive error hierarchy for subprocess failures

Key directories:

- `lib/process_executer/` - Core library code
- `spec/` - RSpec test suite
- `doc/` - YARD-generated documentation
- `pkg/` - Built gem packages

## Coding Standards

### Ruby Style

- Use `frozen_string_literal: true` at the top of all Ruby files
- Follow Ruby community style guide (Rubocop-compatible)
- Require Ruby 3.1.0+ features and idioms
- Use keyword arguments for methods with multiple parameters
- Prefer `private` over `private :method_name` for method visibility
- Use pattern matching for complex conditional logic where appropriate

### Code Organization

- Keep classes focused and single-responsibility
- Use modules for mixins and namespace organization
- Place related classes in the same file only if they're tightly coupled
- One public class per file as a general rule
- Group related functionality in subdirectories (`options/`, `destinations/`,
  `commands/`)

### Naming Conventions

- Classes/Modules: PascalCase (e.g., `MonitoredPipe`, `ResultWithCapture`)
- Methods/variables: snake_case (e.g., `spawn_with_timeout`, `elapsed_time`)
- Constants: UPPER_SNAKE_CASE (e.g., `DEFAULT_TIMEOUT`)
- Predicate methods: end with `?` (e.g., `timed_out?`, `success?`)
- Dangerous methods: end with `!` if they modify in place
- Instance variables: `@variable_name`
- Avoid class variables; prefer class instance variables or constants

### Documentation

- Use YARD syntax for all public methods
- Include `@param`, `@return`, `@raise`, `@example`, `@overload` tags
- Document edge cases, platform differences, and security considerations
- Keep method documentation up-to-date with implementation
- Add `@api private` for internal-only methods
- Use `@api public` for public API methods
- Document Process.spawn compatibility and deviations

Example:

```ruby
# Spawns a command with timeout support
#
# @param command [Array<String>] the command to execute (compatible with Process.spawn)
# @param options [Hash] execution options including :timeout_after
# @option options [Numeric, nil] :timeout_after seconds before SIGKILL (0 or nil means no timeout)
# @return [ProcessExecuter::Result] result object with status and metadata
# @raise [ProcessExecuter::SpawnError] if the process fails to spawn
# @raise [ProcessExecuter::TimeoutError] if the process times out
# @example Run command with 5-second timeout
#   result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 5)
#   result.timed_out? #=> true
# @api public
def spawn_with_timeout(*command, **options)
  # implementation
end
```

## Key Technical Details

### Core Methods Hierarchy

The module provides three main methods, each building on the previous:

1. **`spawn_with_timeout`**: Base method extending `Process.spawn` with timeout
   support
   - Accepts all `Process.spawn` options plus `:timeout_after`
   - Returns a `Result` object (decorator for `Process::Status`)
   - Uses `Process.wait` with timeout monitoring

2. **`run`**: Extends `spawn_with_timeout` with enhanced I/O redirection
   - Supports `MonitoredPipe` for streaming to multiple destinations
   - Additional options: `:out`, `:err`, `:logger`, `:on_good_status`, etc.
   - Can raise errors based on exit status.

3. **`run_with_capture`**: Extends `run` to automatically capture stdout/stderr
   - Returns `ResultWithCapture` with `out` and `err` attributes
   - Captures output to strings while optionally streaming elsewhere

### Process.spawn Compatibility

- All methods accept `Process.spawn`'s command formats:
  - Single string: `'echo hello | grep hello'`
  - Exe + args: `'echo', 'hello'`
  - Environment + command: `{'VAR'=>'value'}, 'echo $VAR'`
- Supports all `Process.spawn` execution options (`:chdir`, `:umask`, `:in`, `:out`,
  `:err`, etc.)
- Extends but doesn't replace `Process.spawn` behavior

### Result Objects

- **`Result`**: Decorates `Process::Status` with additional metadata
  - `command`, `options`, `elapsed_time`, `timed_out?`
  - Delegates all `Process::Status` methods (`exitstatus`, `success?`, `signaled?`,
    etc.)

- **`ResultWithCapture`**: Extends `Result` with captured output
  - `out` and `err` attributes contain captured strings
  - Useful for programmatic output processing

### MonitoredPipe System

`MonitoredPipe` enables output streaming to multiple destinations:
- Wraps an IO pipe (created internally)
- Monitors pipe in background thread
- Writes to multiple destinations (IO, String, Logger, custom)
- Handles encoding conversions
- Properly closes and cleans up resources

Destinations:
- `StringDestination`: Captures to String
- `IODestination`: Writes to any IO object
- `LoggerDestination`: Logs each line
- `CallableDestination`: Calls a block/proc for each chunk

### Options Classes

Type-safe option handling using dedicated classes:
- `SpawnWithTimeoutOptions`: For `spawn_with_timeout` method
- `RunOptions`: For `run` method
- Validates and normalizes options
- Provides clear error messages for invalid options

### Error Hierarchy

Comprehensive error handling with specific exception classes:

- `ProcessExecuter::Error`: Base class for all gem errors
- `ProcessExecuter::ArgumentError`: Invalid arguments provided
- `ProcessExecuter::CommandError`: Base for command execution errors
  - `ProcessExecuter::SpawnError`: Process failed to spawn
  - `ProcessExecuter::FailedError`: Command exited unsuccessfully
  - `ProcessExecuter::SignaledError`: Process was killed by signal
  - `ProcessExecuter::TimeoutError`: Process exceeded timeout
- `ProcessExecuter::ProcessIOError`: IO operation failures

All command errors include command, options, and result for debugging.

## Development Methodology

### Test Driven Development (TDD)

**This project strictly follows TDD practices. All code MUST be written using the
Red-Green-Refactor cycle.**

You are an expert software engineer following a strict Test-Driven Development (TDD)
workflow.

**Core TDD Principles**

- **Never write production code without a failing test first.**
- **Bug Fixes Start with Tests:** Before fixing any bug, write a failing test that
  demonstrates the bug and fails in the expected way. Only then fix the code to make
  the test pass.
- **Tests Drive Design:** Let the test dictate the API and architecture. If the test
  is hard to write, the design is likely wrong. When this happens, stop and suggest
  one or more design alternatives. Offer to stash any current changes and work on the
  design improvements first before continuing with the original task.
- **Write Tests Incrementally:** Focus on small, atomic tests that verify exactly one
  logical behavior.
- **No Implementation in Advance:** Only write the code strictly needed to pass the
  current test.

**Phase 1: Analysis & Planning** Before writing any code:

1. Analyze the request.
2. Create a checklist of small, isolated implementation steps.

**Phase 2: The RED-GREEN-REFACTOR Cycle** Execute the checklist items one by one.
Build each checklist item using multiple RED-GREEN iterations if needed. Follow with
a REFACTOR step before moving to the next checklist item.

You must complete the _entire_ cycle for a checklist item before moving to the next.

**Completion Criteria for a Checklist Item:**
- All functionality for that item is implemented
- All related tests pass
- Code is clean and well-factored
- Ready to move to the next independent item

1. **RED (The Failing Test):**

   - Write a single, focused, failing test or extend an existing test for the current
     checklist item
   - Only write enough of a test to get an expected, failing result (the test should
     fail for the *right* reason)
   - **Execute** the test using the terminal command `bundle exec rspec
     spec/path/to/spec.rb` and **analyze** the output.
   - Confirm it fails with an _expected_ error (e.g., assertion failure or missing
     definition).
   - **Validation:** If the test passes without implementation, the test is invalid
     or the logic already exists—revise or skip.

2. **GREEN (Make it Pass):**

   - Write the _minimum amount of code_ required to make the test pass.
   - It is acceptable to use hardcoded values or "quick and dirty" logic here just to
     get to green, even if this means intentionally writing clearly suboptimal code
     that you will improve during the REFACTOR step.
   - **Execute** the test again using the terminal command `bundle exec rspec
     spec/path/to/spec.rb` and **verify** it passes.
   - _Constraint:_ Do not implement future features or optimizations yet.

3. **REFACTOR (Make it Right):**

   - **Critical Step:** You must consider refactoring _before_ starting the next
     checklist item.
   - Remove duplication, improve variable names, and apply design patterns.
   - Skip this step only if the code is already clean and simple—avoid
     over-engineering.
   - **Execute** all tests using the terminal command `bundle exec rake` and
     **verify** they still pass.
   - **Test Independence:** Verify tests can run independently in any order.

**Additional Guidelines**

These supplement the RED-GREEN-REFACTOR cycle:

- If the implementation reveals a complex logic gap, add it to your checklist, but
  finish the current cycle first.
- Do not generate a "wall of text." Keep code blocks small and focused on the current
  step.
- Stop and ask for clarification if a step is ambiguous.

#### Example TDD Session

```ruby
# Step 1: Write first failing test
RSpec.describe ProcessExecuter do
  describe '.spawn_with_timeout' do
    it 'returns a Result object' do
      result = ProcessExecuter.spawn_with_timeout('echo hello')
      expect(result).to be_a(ProcessExecuter::Result)
    end
  end
end

# Run test → RED (method doesn't exist or returns wrong type)

# Step 2: Minimal code to pass
module ProcessExecuter
  FakeStatus = Struct.new(:success?)

  def self.spawn_with_timeout(*command, **options)
    status = FakeStatus.new(true)
    Result.new(status, command, options, 0.1, false)
  end
end

# Run test → GREEN

# Step 3: Write next failing test
it 'executes the command and returns its status' do
  result = ProcessExecuter.spawn_with_timeout('exit 0')
  expect(result.success?).to be true
end

# Run test → RED (dummy status doesn't have success? or returns wrong value)

# Step 4: Implement actual execution
def self.spawn_with_timeout(*command, **options)
  start_time = Time.now
  pid = Process.spawn(*command, **options)
  _pid, status = Process.wait2(pid)
  elapsed_time = Time.now - start_time
  Result.new(status, command, options, elapsed_time, false)
end

# Run test → GREEN

# Step 5: REFACTOR - Extract time tracking, improve variable names
def self.spawn_with_timeout(*command, **options)
  start_time = Time.now
  pid = Process.spawn(*command, **options)
  _pid, status = Process.wait2(pid)
  elapsed_time = Time.now - start_time
  Result.new(status, command, options, elapsed_time, false)
end

# Run all tests → Still GREEN
# Checklist item complete, move to next item...
```

## Testing Requirements

### Test Framework

- Use **RSpec** for all tests
- Tests located in `spec/` directory
- Main test files:
  - `process_executer_run_spec.rb` - Tests for `run` method
  - `process_executer_run_with_capture_spec.rb` - Tests for `run_with_capture`
  - `process_executer_spawn_with_timeout_spec.rb` - Tests for `spawn_with_timeout`
  - `process_executer/destinations_spec.rb` - Tests for destination classes
  - `process_executer/monitored_pipe_spec.rb` - Tests for MonitoredPipe
- Use `spec_helper.rb` for shared configuration

### Coverage Target

Maintain **high code coverage** (aim for 90%+) through TDD practice. SimpleCov is
configured in the project.

### Test Organization

```ruby
RSpec.describe ProcessExecuter do
  describe '.spawn_with_timeout' do
    context 'when command succeeds' do
      it 'returns a successful result' do
        result = ProcessExecuter.spawn_with_timeout('exit 0')
        expect(result).to be_success
      end
    end

    context 'when command times out' do
      it 'kills the process and marks result as timed out' do
        result = ProcessExecuter.spawn_with_timeout('sleep 10', timeout_after: 0.01)
        expect(result).to be_timed_out
        expect(result).to be_signaled
      end
    end
  end
end
```

### Critical Test Cases

- Command execution with various formats (string, exe+args, env+command)
- Timeout handling (processes that timeout vs. complete within timeout)
- Signal handling (SIGTERM, SIGKILL, etc.)
- Output capture and streaming
- MonitoredPipe with multiple destinations
- Error conditions (spawn failures, IO errors)
- Cross-platform compatibility (Mac, Linux, Windows)
- Different Ruby implementations (MRI, TruffleRuby, JRuby)
- Edge cases: unicode output, binary data, large output, encoding issues

### Test Helpers

Helper methods for common test patterns:
- Use temporary files for I/O redirection tests
- Mock time for elapsed_time testing when needed
- Use realistic commands that work cross-platform (e.g., `echo`, `exit`)
- Avoid platform-specific commands unless testing platform-specific behavior

## Running Tests

```bash
# Run all tests
bundle exec rake

# Run specific test file
bundle exec rspec spec/process_executer_run_spec.rb

# Run specific test by line number
bundle exec rspec spec/process_executer_run_spec.rb:42

# Run tests with coverage
bundle exec rake
# (SimpleCov is configured to run automatically)

# View coverage report
open coverage/index.html
```

## Ruby Version Compatibility

### Current Support

- Minimum: Ruby 3.1.0
- Actively tested: MRI 3.1+, TruffleRuby 24+, JRuby 9.4+
- Platforms: Mac, Linux, Windows
- CI tests on multiple Ruby versions and platforms

### Platform Considerations

**Cross-Platform Compatibility:**
- Use `Process.spawn` which works on all platforms
- Avoid Unix-specific signals unless necessary
- Test command execution on all platforms
- Handle Windows path separators when needed
- Be aware of shell differences (sh vs cmd.exe)

**Signal Handling:**
- SIGKILL works on all platforms for timeout
- Other signals may have platform-specific behavior
- Windows has limited signal support

**IO and Encoding:**
- Handle different default encodings across platforms
- Test with UTF-8 and other encodings
- Binary mode vs. text mode differences on Windows

## Configuration & Settings

### Gemspec Configuration

Located in `process_executer.gemspec`:

- Minimal runtime dependencies (only standard library)
- Development dependencies in Gemfile
- `required_ruby_version >= 3.1.0`
- Supports multiple Ruby implementations

### Rake Configuration

Located in `Rakefile`:

- Default task runs RSpec tests
- SimpleCov for coverage tracking
- Rubocop for linting
- YARD for documentation generation

## Error Handling

- Raise specific exception classes from `ProcessExecuter::Error` hierarchy
- Always include relevant context (command, options, result) in exceptions
- Provide helpful error messages that guide users to solutions
- Handle platform-specific errors gracefully
- Document all error conditions in method YARD docs
- Never swallow exceptions silently

**Error Design Principles:**
- Inherit from `ProcessExecuter::Error` for all gem-specific errors
- Include structured data (not just message strings)
- Make errors programmatically inspectable
- Distinguish between user errors (ArgumentError) and runtime errors (CommandError)

## Performance Considerations

### Process Execution

- Use `Process.spawn` for non-blocking subprocess creation
- Monitor timeout efficiently without busy-waiting
- Clean up resources (pipes, threads) properly
- Handle large output without excessive memory usage

### MonitoredPipe Performance

- Use background threads for pipe monitoring
- Buffer writes efficiently
- Avoid blocking main thread during I/O
- Handle backpressure when destinations are slow

### Memory Management

- Stream large outputs rather than buffering everything
- Close pipes and file descriptors promptly
- Clean up threads after execution
- Be mindful of captured output size in `run_with_capture`

## Documentation

- Keep CHANGELOG.md updated with all user-facing changes
- Update README.md examples when API changes
- Document breaking changes prominently in CHANGELOG
- Use inline YARD comments for comprehensive API documentation
- Generate docs with `bundle exec yard doc`
- Ensure examples in documentation actually work
- Document platform-specific behavior
- Include security considerations (e.g., shell injection risks)

## Key Documents

Always consult these before implementing features:

- **README.md** - Project overview, usage examples, and getting started
- **CHANGELOG.md** - Version history, breaking changes, and migration guides
- **LICENSE.txt** - MIT License
- Full YARD documentation at https://rubydoc.info/gems/process_executer/

## Code Quality Checklist

Before committing, ensure:

**Testing:**
- [ ] **TDD process followed** - Tests written before implementation
- [ ] All tests pass (`bundle exec rake`)
- [ ] No Ruby warnings when running tests

**Code Style:**
- [ ] Code follows Ruby style conventions (Rubocop)
- [ ] YARD documentation for public methods

**Compatibility:**
- [ ] Backward compatibility maintained (unless breaking change)
- [ ] Cross-platform compatibility considered (Windows, macOS, Linux)
- [ ] Cross-Ruby-implementation compatibility (MRI, TruffleRuby, JRuby)

**Documentation & Safety:**
- [ ] CHANGELOG.md updated for user-facing changes
- [ ] Security considerations addressed (command injection, etc.)
- [ ] Resource cleanup (pipes, threads, file descriptors)

## Git Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/) for clear
history:

- `feat: Add capture to multiple destinations` - New functionality
- `fix: Resolve timeout race condition` - Bug fixes
- `docs: Update README examples` - Documentation only
- `test: Add specs for MonitoredPipe encoding` - Adding/updating tests
- `refactor: Simplify Result initialization` - Code restructuring
- `chore: Update dependencies` - Build/tooling changes
- `perf: Optimize pipe monitoring` - Performance improvements

Use descriptive commit messages that explain the "why" not just the "what".

This project uses [release-please](https://github.com/googleapis/release-please) for
automated releases based on conventional commits.

## Pull Request Guidelines

**Branch Strategy:**

1. Ensure local main is up-to-date: `git fetch origin main`
2. Create a new branch from origin/main: `git checkout -b feature/your-feature
   origin/main`
3. Make your changes following TDD
4. Ensure all tests pass and code quality checks pass
5. Push the branch and create a PR

**PR Description Should Include:**

- What problem does this solve?
- What approach was taken?
- Any breaking changes?
- Testing performed (manual and automated)
- Platform-specific considerations
- Related issues/PRs

**Review Checklist:**

- Tests demonstrate the change works
- Documentation updated
- CHANGELOG.md updated if needed
- No breaking changes without major version bump
- Cross-platform compatibility verified

## Special Considerations

### Security

- **Command Injection**: When using single-string commands, be aware of shell
  injection risks
- **Input Validation**: Validate and sanitize user input before passing to commands
- **File Permissions**: Be careful with file descriptors and permissions
- **Resource Limits**: Consider timeout and resource consumption
- Document security implications in YARD comments

### Process.spawn Compatibility

- Maintain full compatibility with `Process.spawn` arguments
- Document any deviations or enhancements clearly
- Test with various `Process.spawn` option combinations
- Support all platforms that Ruby supports

### Thread Safety

- MonitoredPipe uses background threads
- Ensure thread-safe access to shared resources
- Clean up threads properly
- Document thread behavior in YARD comments

### Encoding Handling

ProcessExecuter handles encoding carefully:
- Respects `Encoding.default_external` and `Encoding.default_internal`
- Supports explicit encoding specification
- Handles transcoding between encodings
- Documents encoding behavior in README and YARD

See README.md "Encoding" section for detailed encoding behavior.

## Current Priorities

Based on project status and maintenance needs:

### Stability and Compatibility

1. Maintain Ruby 3.1+ compatibility
2. Keep cross-platform support (Mac, Linux, Windows)
3. Support multiple Ruby implementations (MRI, TruffleRuby, JRuby)
4. Ensure backward compatibility within major versions

### Code Quality

1. Maintain high test coverage (90%+)
2. Follow TDD strictly for all changes
3. Keep Rubocop violations at zero
4. Comprehensive YARD documentation

### Feature Enhancements

Consider these only after TDD test is written:
- Additional destination types for MonitoredPipe
- Enhanced timeout options (grace period before SIGKILL)
- Better error context and debugging information
- Performance optimizations for high-throughput scenarios

### Documentation

- Keep README.md examples current and comprehensive
- Add more real-world examples
- Document common pitfalls and gotchas
- Platform-specific behavior documentation

## Useful Commands

```bash
# Install dependencies
bundle install

# Run full test suite
bundle exec rake

# Run specific spec file
bundle exec rspec spec/process_executer_run_spec.rb

# Run specific test
bundle exec rspec spec/process_executer_run_spec.rb:42

# Generate YARD documentation
bundle exec yard doc

# Start documentation server
bundle exec yard server --reload

# Build gem
bundle exec rake build

# Check code style
bundle exec rubocop

# View coverage report
open coverage/index.html
```

## Getting Help

- Review README.md for usage examples and architecture
- Check CHANGELOG.md for version history and breaking changes
- Read inline YARD documentation in source code
- Browse full API docs at https://rubydoc.info/gems/process_executer/
- Look at existing specs for testing patterns
- Check CI configuration in `.github/workflows/` for supported platforms

## Important Implementation Notes

### When Working with Process.spawn

- Always handle both Hash and non-Hash first arguments (environment)
- Preserve all `Process.spawn` execution options
- Test with various command formats (string vs. array)
- Consider edge cases: empty commands, special characters, Unicode

### When Working with IO Redirection

- Always close file descriptors properly
- Handle both blocking and non-blocking IO
- Consider buffer sizes and backpressure
- Test with large output volumes
- Handle encoding conversions correctly

### When Working with Timeouts

- Use `Process.wait` with timeout, not sleep loops
- Send SIGKILL for reliable termination
- Handle race conditions (process exits just as timeout occurs)
- Accurately track elapsed time
- Clean up zombie processes

### When Working with Threads

- Always join or kill threads before method returns
- Handle exceptions in background threads
- Avoid race conditions with shared state
- Clean up resources even if exceptions occur
- Test thread cleanup thoroughly
