# Process Spawn Test

These tests verify that `Process.spawn`, `Process.wait`, and `Process.wait2` work
correctly across different Ruby implementations and operating systems.

This test suite is particularly important for verifying JRuby behavior on Windows,
where historically there have been issues with subprocess status reporting.

## Tests

The test suite includes:

* Test that `Process#wait` sets the global `$CHILD_STATUS` variable
* Test that `Process#wait2` returns a non-nil status

## Running the Tests

There is no Gemfile in `process_spawn_test/`, so bundler walks up to the repo root and uses the main project's Gemfile. From the repository root:

```bash
cd process_spawn_test && bundle exec rspec
```

Alternatively, you can stay at the root and run:

```bash
bundle exec rspec process_spawn_test/spec/test_spec.rb
```

## GitHub Actions Workflow

The workflow file `.github/workflows/process-spawn-test.yml` can be manually triggered to run these tests on:
- MRI Ruby and JRuby
- Ubuntu (Linux) and Windows

To run the workflow, go to the Actions tab in GitHub and select "Process.spawn Test" from the workflow list.
