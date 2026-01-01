# frozen_string_literal: true

require "json"
require "time"

module StimulusViz
  class Scanner
    attr_reader :root

    def initialize(root:)
      @root = root
      @controllers = []
      @bindings = []
      @binding_counter = 0
    end

    def run
      scan_controllers
      scan_erb_files
      generate_lint_results
      
      {
        meta: {
          root: @root,
          generated_at: Time.now.iso8601
        },
        controllers: aggregate_controllers,
        bindings: @bindings,
        lint: @lint_results
      }
    end

    private

    def scan_controllers
      controller_pattern = File.join(@root, "app/javascript/controllers/**/*_controller.{js,ts}")
      Dir.glob(controller_pattern).each do |file_path|
        relative_path = file_path.sub(@root + "/", "")
        basename = File.basename(file_path, ".*")
        
        # Convert filename to controller name: message_form_controller -> message-form
        controller_name = basename.sub(/_controller$/, "").tr("_", "-")
        
        @controllers << {
          name: controller_name,
          module: relative_path,
          file_path: file_path
        }
      end
    end

    def scan_erb_files
      erb_pattern = File.join(@root, "app/views/**/*.erb")
      Dir.glob(erb_pattern).each do |file_path|
        scan_erb_file(file_path)
      end
    end

    def scan_erb_file(file_path)
      content = File.read(file_path)
      relative_path = file_path.sub(@root + "/", "")
      
      # Find HTML tags by parsing character by character to handle quoted attributes
      i = 0
      while i < content.length
        if content[i] == '<' && content[i + 1] =~ /[a-zA-Z]/
          # Found start of tag, find the end
          tag_start = i
          i += 1
          in_quotes = false
          quote_char = nil
          
          while i < content.length
            char = content[i]
            
            if !in_quotes && (char == '"' || char == "'")
              in_quotes = true
              quote_char = char
            elsif in_quotes && char == quote_char
              in_quotes = false
              quote_char = nil
            elsif !in_quotes && char == '>'
              # Found end of tag
              tag_end = i
              full_tag = content[tag_start..tag_end]
              
              if full_tag.include?('data-')
                line_number = content[0...tag_start].count("\n") + 1
                process_element(full_tag, relative_path, line_number)
              end
              break
            end
            
            i += 1
          end
        end
        i += 1
      end
    end

    def process_element(element, file_path, line_number)
      @binding_counter += 1
      binding_id = "el_%04d" % @binding_counter
      
      # Extract id attribute for better selector
      id_match = element.match(/id=["']([^"']+)["']/)
      selector_suffix = id_match ? "##{id_match[1]}" : ""
      selector = "#{file_path}:#{line_number} <#{element[1..20]}...#{selector_suffix}>"
      
      binding = {
        id: binding_id,
        selector: selector,
        controllers: extract_controllers(element),
        actions: extract_actions(element),
        targets: extract_targets(element),
        values: extract_values(element)
      }
      
      # Mark as broken if has controllers but no interactions
      if !binding[:controllers].empty? && 
         binding[:actions].empty? && 
         binding[:targets].empty? && 
         binding[:values].empty?
        binding[:broken] = true
      end
      
      @bindings << binding
    end

    def extract_controllers(element)
      match = element.match(/data-controller=["']([^"']+)["']/m)
      return [] unless match
      
      match[1].split(/\s+/).reject(&:empty?)
    end

    def extract_actions(element)
      match = element.match(/data-action=["']([^"']+)["']/m)
      return [] unless match
      
      match[1].split(/\s+/).reject(&:empty?)
    end

    def extract_targets(element)
      targets = []
      
      # Single target: data-controller-target="name"
      element.scan(/data-([^-\s]+)-target=["']([^"']+)["']/m) do |controller, name|
        targets << {
          controller: controller.tr("_", "-"),
          name: name,
          selector: "(static)"
        }
      end
      
      # Multiple targets: data-controller-targets="name1 name2"
      element.scan(/data-([^-\s]+)-targets=["']([^"']+)["']/m) do |controller, names|
        names.split(/\s+/).each do |name|
          targets << {
            controller: controller.tr("_", "-"),
            name: name,
            selector: "(static)"
          }
        end
      end
      
      targets
    end

    def extract_values(element)
      values = []
      
      element.scan(/data-([^-\s]+)-([^-\s]+(?:-[^-\s]+)*)-value=["']([^"']+)["']/m) do |controller, value_name, value|
        # Convert kebab-case to camelCase
        camel_name = value_name.split("-").map.with_index do |part, index|
          index == 0 ? part : part.capitalize
        end.join
        
        values << {
          controller: controller.tr("_", "-"),
          name: camel_name,
          value: value
        }
      end
      
      values
    end

    def aggregate_controllers
      @controllers.map do |controller|
        # Count elements that use this controller
        elements_count = @bindings.count { |b| b[:controllers].include?(controller[:name]) }
        
        # Collect unique actions, targets, values for this controller
        actions = []
        targets = []
        values = []
        
        @bindings.each do |binding|
          next unless binding[:controllers].include?(controller[:name])
          
          # Extract actions for this controller
          binding[:actions].each do |action|
            if action =~ /^(.+)->([^#]+)#(.+)$/
              _event, ctrl, method = $1, $2, $3
              actions << method if ctrl == controller[:name]
            end
          end
          
          # Extract targets for this controller
          binding[:targets].each do |target|
            targets << target[:name] if target[:controller] == controller[:name]
          end
          
          # Extract values for this controller
          binding[:values].each do |value|
            values << value[:name] if value[:controller] == controller[:name]
          end
        end
        
        {
          name: controller[:name],
          module: controller[:module],
          elements: elements_count,
          actions: actions.uniq.sort,
          targets: targets.uniq.sort,
          values: values.uniq.sort
        }
      end
    end

    def generate_lint_results
      @lint_results = []
      
      controller_names = @controllers.map { |c| c[:name] }
      
      @bindings.each do |binding|
        # Check for unknown controllers
        binding[:controllers].each do |controller|
          unless controller_names.include?(controller)
            @lint_results << {
              level: "warn",
              title: "Unknown controller",
              detail: "Controller '#{controller}' is referenced but not found in controllers directory",
              where: binding[:selector]
            }
          end
        end
        
        # Check for suspicious actions
        binding[:actions].each do |action|
          unless action =~ /^[^->]+->[^#]+#[^#]+$/
            @lint_results << {
              level: "warn", 
              title: "Suspicious action format",
              detail: "Action '#{action}' doesn't match expected 'event->controller#method' format",
              hint: "Expected format: 'click->controller#method'",
              where: binding[:selector]
            }
          end
        end
        
        # Check for empty bindings
        if !binding[:controllers].empty? && 
           binding[:actions].empty? && 
           binding[:targets].empty? && 
           binding[:values].empty?
          @lint_results << {
            level: "info",
            title: "Empty binding",
            detail: "Element has data-controller but no actions, targets, or values",
            hint: "Consider adding data-action, targets, or values to make the controller useful",
            where: binding[:selector]
          }
        end
      end
    end
  end
end