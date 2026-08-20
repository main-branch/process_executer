# Process Spawn Test

These tests verify that `Process.spawn`, `Process.wait`, and `Process.wait2` work
correctly across different Ruby implementations and operating systems.

This test suite is particularly important for verifying JRuby behavior on Windows,
where historically there have been issues with subprocess status reporting. See
[jruby/jruby#7515](https://github.com/jruby/jruby/issues/7515).

## Tests

The test suite includes:

* Test that `Process#wait` sets the global `$CHILD_STATUS` variable
* Test that `Process#wait` reports the exit status of a child that failed
* Test that `Process#wait` blocks until the child exits
* Test that `Process#wait2` returns a non-nil status
* Test that `Process#wait2` returns the pid and status of a child that failed

## Spawn backends

Set `SPAWN_BACKEND` to choose which spawn implementation the examples exercise:

| Value | Meaning |
| --- | --- |
| `stock` (default) | Whatever the running Ruby provides |
| `subspawn` | [byteit101/subspawn](https://github.com/byteit101/subspawn) replaces `Process.spawn` and the `wait` family |

JRuby has a built-in opt-in for SubSpawn, `USE_SUBSPAWN=true`, but it refuses to
honor it on the one platform this suite cares about: `Ruby.java` logs
`env USE_SUBSPAWN=true is unsupported on Windows at this time` and loads nothing.
So `spec_helper.rb` requires `subspawn/replace-builtin` itself instead.

Two things keep the `subspawn` backend from being a plain `gem install subspawn --pre`:

* The published `subspawn` 0.2.0.pre1 cannot be installed on JRuby at all. Its
  `engine-hacks` dependency was only ever pushed as a `ruby` platform gem carrying
  a C extension; the `java` platform build that its gemspec provides for was never
  published, so RubyGems tries to compile the C extension under JRuby.
* master is newer than the RC and carries fixes the RC does not have.

So the workflow clones the repo and builds the gemspecs with the active Ruby, which
produces the java-platform `engine-hacks` gem.

## Running the Tests

There is no Gemfile in `process_spawn_test/`, so bundler walks up to the repo root and uses the main project's Gemfile. From the repository root:

```bash
cd process_spawn_test && bundle exec rspec
```

Alternatively, you can stay at the root and run:

```bash
bundle exec rspec process_spawn_test/spec/test_spec.rb
```

SubSpawn is not in that Gemfile. To run the `subspawn` backend, install it as a
system gem and run `rspec` directly, outside the bundle:

```bash
SPAWN_BACKEND=subspawn rspec spec/test_spec.rb
```

## GitHub Actions Workflow

The workflow file `.github/workflows/process-spawn-test.yml` can be manually triggered to run these tests on:
- MRI Ruby and JRuby
- Ubuntu (Linux) and Windows
- the `stock` and `subspawn` spawn backends (`subspawn` on JRuby only)

To run the workflow, go to the Actions tab in GitHub and select "Process.spawn Test" from the workflow list.
