# frozen_string_literal: true

require "thor"
require "json"

module StimulusViz
  class CLI < Thor
    desc "scan [OPTIONS]", "Scan Rails project for Stimulus controllers and bindings"
    option :root, type: :string, default: ".", desc: "Root path of Rails project"
    option :out, type: :string, default: ".stimulus-viz.json", desc: "Output file path"
    def scan
      root_path = File.expand_path(options[:root])
      output_path = File.expand_path(options[:out])
      
      scanner = Scanner.new(root: root_path)
      result = scanner.run
      
      File.write(output_path, JSON.pretty_generate(result))
      puts "Scan completed. Results saved to #{output_path}"
    end

    desc "list [OPTIONS]", "List controllers from cache"
    option :cache, type: :string, default: ".stimulus-viz.json", desc: "Cache file path"
    def list
      data = load_cache(options[:cache])
      
      puts "Controllers:"
      data[:controllers].each do |controller|
        puts "  #{controller[:name]} (#{controller[:module]})"
        puts "    Elements: #{controller[:elements]}"
        puts "    Actions: #{controller[:actions].join(', ')}" unless controller[:actions].empty?
        puts "    Targets: #{controller[:targets].join(', ')}" unless controller[:targets].empty?
        puts "    Values: #{controller[:values].join(', ')}" unless controller[:values].empty?
        puts
      end
    end

    desc "bindings [OPTIONS]", "Show DOM bindings"
    option :cache, type: :string, default: ".stimulus-viz.json", desc: "Cache file path"
    option :controller, type: :string, desc: "Filter by controller name"
    def bindings
      data = load_cache(options[:cache])
      
      bindings = data[:bindings]
      if options[:controller]
        bindings = bindings.select { |b| b[:controllers].include?(options[:controller]) }
      end
      
      puts "Bindings:"
      bindings.each do |binding|
        puts "  #{binding[:id]} - #{binding[:selector]}"
        puts "    Controllers: #{binding[:controllers].join(', ')}" unless binding[:controllers].empty?
        puts "    Actions: #{binding[:actions].join(', ')}" unless binding[:actions].empty?
        puts "    Targets: #{binding[:targets].map { |t| "#{t[:controller]}.#{t[:name]}" }.join(', ')}" unless binding[:targets].empty?
        puts "    Values: #{binding[:values].map { |v| "#{v[:controller]}.#{v[:name]}=#{v[:value]}" }.join(', ')}" unless binding[:values].empty?
        puts "    ⚠️  BROKEN" if binding[:broken]
        puts
      end
    end

    desc "lint [OPTIONS]", "Run lint checks"
    option :cache, type: :string, default: ".stimulus-viz.json", desc: "Cache file path"
    option :fail_on, type: :string, default: "none", desc: "Fail on level: info|warn|error|none"
    def lint
      data = load_cache(options[:cache])
      
      puts "Lint Results:"
      exit_code = 0
      fail_levels = %w[info warn error]
      fail_threshold = fail_levels.index(options[:fail_on]) || -1
      
      data[:lint].each do |issue|
        level_index = fail_levels.index(issue[:level]) || -1
        exit_code = 1 if level_index >= fail_threshold && fail_threshold >= 0
        
        puts "  [#{issue[:level].upcase}] #{issue[:title]}"
        puts "    #{issue[:detail]}"
        puts "    Hint: #{issue[:hint]}" if issue[:hint]
        puts "    Location: #{issue[:where]}" if issue[:where]
        puts
      end
      
      exit(exit_code) if exit_code > 0
    end

    desc "export [OPTIONS]", "Export data in different formats"
    option :cache, type: :string, default: ".stimulus-viz.json", desc: "Cache file path"
    option :format, type: :string, required: true, desc: "Output format: json|dot"
    option :out, type: :string, required: true, desc: "Output file path"
    def export
      data = load_cache(options[:cache])
      
      case options[:format]
      when "json"
        File.write(options[:out], JSON.pretty_generate(data))
      when "dot"
        dot_content = generate_dot(data)
        File.write(options[:out], dot_content)
      else
        puts "Unknown format: #{options[:format]}"
        exit(1)
      end
      
      puts "Exported to #{options[:out]} in #{options[:format]} format"
    end

    private

    def load_cache(cache_path)
      unless File.exist?(cache_path)
        puts "Cache file not found: #{cache_path}"
        puts "Run 'stimulus-viz scan' first"
        exit(1)
      end
      
      JSON.parse(File.read(cache_path), symbolize_names: true)
    end

    def generate_dot(data)
      lines = ["digraph stimulus {"]
      lines << "  rankdir=LR;"
      lines << "  node [shape=box];"
      
      # Add controller nodes
      data[:controllers].each do |controller|
        lines << "  \"#{controller[:name]}\" [label=\"#{controller[:name]}\\n(#{controller[:elements]} elements)\"];"
      end
      
      # Add binding edges
      data[:bindings].each do |binding|
        binding[:controllers].each do |controller|
          lines << "  \"#{binding[:selector]}\" -> \"#{controller}\" [label=\"data-controller\"];"
        end
        
        binding[:actions].each do |action|
          if action =~ /^(.+)->(.+)#(.+)$/
            event, controller_method = $1, $2
            lines << "  \"#{event}\" -> \"#{controller_method}\" [label=\"#{action}\"];"
          end
        end
      end
      
      lines << "}"
      lines.join("\n")
    end
  end
end