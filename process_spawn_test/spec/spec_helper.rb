# frozen_string_literal: true

require 'rspec'

# Which spawn implementation these examples exercise: 'stock' (whatever the
# running Ruby provides) or 'subspawn' (byteit101/subspawn).
SPAWN_BACKEND = ENV.fetch('SPAWN_BACKEND', 'stock')

# JRuby has a built-in opt-in for SubSpawn, `USE_SUBSPAWN=true`, but it refuses
# to honor it on the one platform jruby/jruby#7515 is about: Ruby.java logs
# "env USE_SUBSPAWN=true is unsupported on Windows at this time" and loads
# nothing. Require the replacement shim directly so the Windows job actually
# runs against SubSpawn.
require 'subspawn/replace-builtin' if SPAWN_BACKEND == 'subspawn'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    warn "Ruby:          #{RUBY_DESCRIPTION}"
    warn "spawn backend: #{SPAWN_BACKEND}"
    # Records whether the shim really took effect, and which backend it picked.
    warn "SubSpawn:      #{defined?(SubSpawn) ? SubSpawn::Platform : '(not loaded)'}"
  end
end
