# frozen_string_literal: true

require_relative "lib/discorb/voice/version"

Gem::Specification.new do |spec|
  spec.name = "discorb-voice"
  spec.version = Discorb::Voice::VERSION
  spec.authors = ["sevenc-nanashi"]
  spec.email = ["sevenc-nanashi@sevenbot.jp"]

  spec.summary = "Gem for connecting voice channels with discorb."
  spec.homepage = "https://github.com/discorb-lib/discorb-voice"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/discorb-lib/discorb-voice"
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "discorb", ">= 0.13.0"
  spec.add_dependency "ffi", ">= 1.15.3"
  spec.add_dependency "rbnacl"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
