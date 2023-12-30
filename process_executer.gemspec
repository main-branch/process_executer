# frozen_string_literal: true

require_relative 'lib/process_executer/version'

Gem::Specification.new do |spec|
  spec.name = 'process_executer'
  spec.version = ProcessExecuter::VERSION
  spec.authors = ['James Couball']
  spec.email = ['jcouball@yahoo.com']

  spec.summary = 'An API for executing commands in a subprocess'
  spec.description = 'An API for executing commands in a subprocess'
  spec.homepage = 'https://github.com/main-branch/process_executer'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/main-branch/process_executer'
  spec.metadata['changelog_uri'] = 'https://rubydoc.info/gems/process_executer/file/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_development_dependency 'bump', '~> 0.10'
  spec.add_development_dependency 'bundler-audit', '~> 0.9'
  spec.add_development_dependency 'create_github_release', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.10'
  spec.add_development_dependency 'rubocop', '~> 1.36'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'simplecov-lcov', '~> 0.8'

  unless RUBY_PLATFORM == 'java'
    spec.add_development_dependency 'redcarpet', '~> 3.5'
    spec.add_development_dependency 'yard', '~> 0.9', '>= 0.9.28'
    spec.add_development_dependency 'yardstick', '~> 0.9'
  end

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
