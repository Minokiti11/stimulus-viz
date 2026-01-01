# frozen_string_literal: true

require "test_helper"

class TestScanner < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("stimulus_viz_test")
    
    # Copy sample_app from fixtures
    sample_app_source = File.join(__dir__, "fixtures/sample_apps/7_0/ch11/sample_app")
    if Dir.exist?(sample_app_source)
      FileUtils.cp_r(sample_app_source, File.join(@tmpdir, "sample_app"))
      @test_root = File.join(@tmpdir, "sample_app")
    else
      # Fallback: create minimal structure
      @test_root = @tmpdir
    end
    
    setup_stimulus_files
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_scan_controllers
    scanner = StimulusViz::Scanner.new(root: @test_root)
    result = scanner.run
    
    assert_includes result[:controllers].map { |c| c[:name] }, "presence"
    
    presence_controller = result[:controllers].find { |c| c[:name] == "presence" }
    assert_equal "app/javascript/controllers/presence_controller.js", presence_controller[:module]
  end

  def test_scan_bindings
    scanner = StimulusViz::Scanner.new(root: @test_root)
    result = scanner.run
    
    assert result[:bindings].any? { |b| b[:controllers].include?("presence") }
    
    presence_binding = result[:bindings].find { |b| b[:controllers].include?("presence") }
    assert_includes presence_binding[:actions], "turbo:before-stream-render->presence#highlight"
    assert presence_binding[:targets].any? { |t| t[:controller] == "presence" && t[:name] == "list" }
    assert presence_binding[:values].any? { |v| v[:controller] == "presence" && v[:name] == "fadeMs" }
  end

  def test_lint_unknown_controller
    # Add binding with unknown controller
    view_content = <<~HTML
      <div data-controller="unknown-controller">
        <span data-action="click->unknown-controller#test"></span>
      </div>
    HTML
    
    File.write(File.join(@test_root, "app/views/test/unknown.html.erb"), view_content)
    
    scanner = StimulusViz::Scanner.new(root: @test_root)
    result = scanner.run
    
    unknown_warnings = result[:lint].select { |l| l[:level] == "warn" && l[:title] == "Unknown controller" }
    assert unknown_warnings.any? { |w| w[:detail].include?("unknown-controller") }
  end

  def test_lint_suspicious_action
    view_content = <<~HTML
      <div data-controller="presence">
        <span data-action="invalid-action-format"></span>
      </div>
    HTML
    
    File.write(File.join(@test_root, "app/views/test/suspicious.html.erb"), view_content)
    
    scanner = StimulusViz::Scanner.new(root: @test_root)
    result = scanner.run
    
    suspicious_warnings = result[:lint].select { |l| l[:level] == "warn" && l[:title] == "Suspicious action format" }
    assert suspicious_warnings.any? { |w| w[:detail].include?("invalid-action-format") }
  end

  def test_lint_empty_binding
    view_content = <<~HTML
      <div data-controller="presence">
        <!-- No actions, targets, or values -->
      </div>
    HTML
    
    File.write(File.join(@test_root, "app/views/test/empty.html.erb"), view_content)
    
    scanner = StimulusViz::Scanner.new(root: @test_root)
    result = scanner.run
    
    empty_infos = result[:lint].select { |l| l[:level] == "info" && l[:title] == "Empty binding" }
    assert empty_infos.any?
  end

  def test_output_schema
    scanner = StimulusViz::Scanner.new(root: @test_root)
    result = scanner.run
    
    # Check meta structure
    assert result[:meta]
    assert result[:meta][:root]
    assert result[:meta][:generated_at]
    
    # Check controllers structure
    assert result[:controllers].is_a?(Array)
    if result[:controllers].any?
      controller = result[:controllers].first
      assert controller[:name]
      assert controller[:module]
      assert controller[:elements].is_a?(Integer)
      assert controller[:actions].is_a?(Array)
      assert controller[:targets].is_a?(Array)
      assert controller[:values].is_a?(Array)
    end
    
    # Check bindings structure
    assert result[:bindings].is_a?(Array)
    if result[:bindings].any?
      binding = result[:bindings].first
      assert binding[:id]
      assert binding[:selector]
      assert binding[:controllers].is_a?(Array)
      assert binding[:actions].is_a?(Array)
      assert binding[:targets].is_a?(Array)
      assert binding[:values].is_a?(Array)
    end
    
    # Check lint structure
    assert result[:lint].is_a?(Array)
    if result[:lint].any?
      lint = result[:lint].first
      assert lint[:level]
      assert lint[:title]
      assert lint[:detail]
    end
  end

  private

  def setup_stimulus_files
    # Create directories
    FileUtils.mkdir_p(File.join(@test_root, "app/javascript/controllers"))
    FileUtils.mkdir_p(File.join(@test_root, "app/views/home"))
    FileUtils.mkdir_p(File.join(@test_root, "app/views/test"))
    
    # Create presence controller
    controller_content = <<~JS
      import { Controller } from "@hotwired/stimulus"
      
      export default class extends Controller {
        static targets = ["list"]
        static values = { fadeMs: Number }
        
        highlight() {
          // Implementation
        }
      }
    JS
    
    File.write(File.join(@test_root, "app/javascript/controllers/presence_controller.js"), controller_content)
    
    # Create view with Stimulus bindings
    view_content = <<~HTML
      <div id="presence"
           data-controller="presence"
           data-action="turbo:before-stream-render->presence#highlight"
           data-presence-target="list"
           data-presence-fade-ms-value="250">
        <ul data-presence-targets="item list">
          <li>Item 1</li>
          <li>Item 2</li>
        </ul>
      </div>
    HTML
    
    File.write(File.join(@test_root, "app/views/home/index.html.erb"), view_content)
  end
end