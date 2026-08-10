# frozen_string_literal: true

require_relative "lib/pickpoint/version"

Gem::Specification.new do |spec|
  spec.name = "pickpoint"
  spec.version = Pickpoint::VERSION
  spec.authors = ["Pickpoint"]
  spec.email = ["hello@pickpoint.io"]

  spec.summary = "Official Ruby SDK for Pickpoint — geocoding, address search, routing, devices"
  spec.description = <<~DESC
    Idiomatic Ruby client for the Pickpoint public HTTP API: geocoding, address
    search, routing, device registry, and client-token minting. No realtime
    tracking client in this gem.
  DESC
  spec.homepage = "https://github.com/pickpoint/ruby-sdk"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = "https://pickpoint.io"
  spec.metadata["documentation_uri"] = "https://pickpoint.io/docs"
  spec.metadata["source_code_uri"] = "https://github.com/pickpoint/ruby-sdk"
  spec.metadata["bug_tracker_uri"] = "https://github.com/pickpoint/ruby-sdk/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z 2>/dev/null`.split("\x0").reject do |f|
      f.start_with?("test/", ".github/", ".git") || f.end_with?(".gem")
    end
  end
  # Fallback when not in a git repo yet
  if spec.files.empty?
    spec.files = Dir["lib/**/*", "LICENSE", "README.md", "VERSION", "pickpoint.gemspec"]
  end

  spec.require_paths = ["lib"]
end
