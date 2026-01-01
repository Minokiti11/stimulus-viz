# frozen_string_literal: true

require "test_helper"

class TestCLI < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("stimulus_viz_cli_test")
    @cache_file = File.join(@tmpdir, "test-cache.json")
    
    setup_test_project
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_scan_command
    capture_io do
      StimulusViz::CLI.start(["scan", "--root", @tmpdir, "--out", @cache_file])
    end
    
    assert File.exist?(@cache_file)
    
    data = JSON.parse(File.read(@cache_file), symbolize_names: true)
    assert data[:meta]
    assert data[:controllers]
    assert data[:bindings]
    assert data[:lint]
  end

  def test_list_command
    # First scan to create cache
    StimulusViz::CLI.start(["scan", "--root", @tmpdir, "--out", @cache_file])
    
    output = capture_io do
      StimulusViz::CLI.start(["list", "--cache", @cache_file])
    end
    
    assert_match(/Controllers:/, output[0])
    assert_match(/test/, output[0])
  end

  def test_bindings_command
    # First scan to create cache
    StimulusViz::CLI.start(["scan", "--root", @tmpdir, "--out", @cache_file])
    
    output = capture_io do
      StimulusViz::CLI.start(["bindings", "--cache", @cache_file])
    end
    
    assert_match(/Bindings:/, output[0])
  end

  def test_lint_command
    # First scan to create cache
    StimulusViz::CLI.start(["scan", "--root", @tmpdir, "--out", @cache_file])
    
    output = capture_io do
      StimulusViz::CLI.start(["lint", "--cache", @cache_file])
    end
    
    assert_match(/Lint Results:/, output[0])
  end

  def test_export_json_command
    # First scan to create cache
    StimulusViz::CLI.start(["scan", "--root", @tmpdir, "--out", @cache_file])
    
    export_file = File.join(@tmpdir, "export.json")
    
    output = capture_io do
      StimulusViz::CLI.start(["export", "--cache", @cache_file, "--format", "json", "--out", export_file])
    end
    
    assert File.exist?(export_file)
    assert_match(/Exported to/, output[0])
  end

  def test_export_dot_command
    # First scan to create cache
    StimulusViz::CLI.start(["scan", "--root", @tmpdir, "--out", @cache_file])
    
    export_file = File.join(@tmpdir, "export.dot")
    
    output = capture_io do
      StimulusViz::CLI.start(["export", "--cache", @cache_file, "--format", "dot", "--out", export_file])
    end
    
    assert File.exist?(export_file)
    dot_content = File.read(export_file)
    assert_match(/digraph stimulus/, dot_content)
    assert_match(/Exported to/, output[0])
  end

  private

  def setup_test_project
    # Create directories
    FileUtils.mkdir_p(File.join(@tmpdir, "app/javascript/controllers"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app/views/test"))
    
    # Create test controller
    controller_content = <<~JS
      import { Controller } from "@hotwired/stimulus"
      
      export default class extends Controller {
        test() {
          console.log("test");
        }
      }
    JS
    
    File.write(File.join(@tmpdir, "app/javascript/controllers/test_controller.js"), controller_content)
    
    # Create view with bindings
    view_content = <<~HTML
      <div data-controller="test">
        <button data-action="click->test#test">Test</button>
      </div>
    HTML
    
    File.write(File.join(@tmpdir, "app/views/test/index.html.erb"), view_content)
  end

  def capture_io
    require "stringio"
    
    old_stdout = $stdout
    old_stderr = $stderr
    
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    yield
    
    [$stdout.string, $stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end