# StimulusViz

[![Gem Version](https://badge.fury.io/rb/stimulus-viz.svg)](https://badge.fury.io/rb/stimulus-viz)

Rails/Hotwire Stimulus visualization tool for static analysis of Stimulus controllers and DOM bindings.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stimulus-viz'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install stimulus-viz

## Setup

If you're using the development version with git submodules:

```bash
git submodule update --init --recursive
```

## Usage

### Scan Rails Project

Scan your Rails project for Stimulus controllers and DOM bindings:

```bash
stimulus-viz scan --root /path/to/rails/project --out .stimulus-viz.json
```

### List Controllers

List all discovered controllers:

```bash
stimulus-viz list --cache .stimulus-viz.json
```

### Show Bindings

Show DOM bindings, optionally filtered by controller:

```bash
stimulus-viz bindings --cache .stimulus-viz.json
stimulus-viz bindings --cache .stimulus-viz.json --controller presence
```

### Lint Analysis

Run lint checks on your Stimulus usage:

```bash
stimulus-viz lint --cache .stimulus-viz.json
stimulus-viz lint --cache .stimulus-viz.json --fail-on warn
```

Lint levels:
- `info`: Empty bindings (controller without actions/targets/values)
- `warn`: Unknown controllers, suspicious action formats
- `error`: Critical issues

### Export Data

Export scan results in different formats:

```bash
# Export as pretty JSON
stimulus-viz export --cache .stimulus-viz.json --format json --out output.json

# Export as DOT graph
stimulus-viz export --cache .stimulus-viz.json --format dot --out graph.dot
```

## Output Schema

The tool generates JSON with the following structure:

```json
{
  "meta": {
    "root": "/path/to/project",
    "generated_at": "2024-01-01T12:00:00Z"
  },
  "controllers": [
    {
      "name": "presence",
      "module": "app/javascript/controllers/presence_controller.js",
      "elements": 3,
      "actions": ["highlight", "connect"],
      "targets": ["list", "item"],
      "values": ["fadeMs", "url"]
    }
  ],
  "bindings": [
    {
      "id": "el_0001",
      "selector": "app/views/home/index.html.erb:42 <div#presence>",
      "controllers": ["presence"],
      "actions": ["turbo:before-stream-render->presence#highlight"],
      "targets": [
        {
          "controller": "presence",
          "name": "list",
          "selector": "(static)"
        }
      ],
      "values": [
        {
          "controller": "presence", 
          "name": "fadeMs",
          "value": "250"
        }
      ],
      "broken": false
    }
  ],
  "lint": [
    {
      "level": "warn",
      "title": "Unknown controller",
      "detail": "Controller 'missing' is referenced but not found",
      "hint": "Check controller name spelling",
      "where": "app/views/test/index.html.erb:10"
    }
  ]
}
```

## Development

After checking out the repo, run:

```bash
git submodule update --init --recursive
bundle install
```

To run tests:

```bash
bundle exec rake test
```

To install this gem onto your local machine:

```bash
bundle exec rake install
```

## Testing

The test suite uses the [yasslab/sample_apps](https://github.com/yasslab/sample_apps) repository as fixtures via git submodules. Tests create temporary directories with minimal Stimulus setups to verify scanning functionality.

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
