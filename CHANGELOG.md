# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-01-01

### Added
- Initial release of StimulusViz
- Static analysis of Stimulus controllers in Rails projects
- DOM binding extraction from ERB templates
- Lint checks for unknown controllers, suspicious actions, and empty bindings
- CLI commands: scan, list, bindings, lint, export
- JSON and DOT export formats
- Comprehensive test suite using yasslab/sample_apps fixtures
- Support for Ruby >= 3.1