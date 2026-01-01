# frozen_string_literal: true

require_relative "lib/stimulus_viz/version"

Gem::Specification.new do |spec|
  spec.name = "stimulus-viz"
  spec.version = StimulusViz::VERSION
  spec.authors = ["Minori Sugimura"]
  spec.email = ["minorex.0117@gmail.com"]

  spec.summary = "Rails/Hotwire Stimulus visualization tool"
  spec.description = "Static analysis tool for Stimulus controllers and DOM bindings in Rails applications"
  spec.homepage = "https://github.com/Minokiti11/stimulus-viz"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "json", "~> 2.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end