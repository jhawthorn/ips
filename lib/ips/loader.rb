# frozen_string_literal: true

module IPS
  # Loads a benchmark file in one of three forms:
  #
  # * *.yml / *.yaml: benchmark_driver style definitions (prelude, benchmark,
  #   teardown). Each benchmark is run as a report, and sees the local
  #   variables defined by the prelude. loop_count is ignored, since ips
  #   chooses its own iteration counts.
  # * a Ruby script that uses IPS itself: loaded as-is.
  # * any other Ruby script: the whole script is benchmarked as one report.
  def self.load_file(path)
    case File.extname(path)
    when ".yml", ".yaml"
      load_yaml(path)
    else
      if File.read(path).match?(/\bIPS\b|\bIps\b|require\s*\(?\s*["']ips/)
        load(File.expand_path(path))
      else
        load_script(path)
      end
    end
  end

  def self.load_script(path)
    iseq = RubyVM::InstructionSequence.compile_file(path)
    label = File.basename(path, ".rb")
    run do |x|
      # Scripts commonly define constants and methods, which would warn on
      # every iteration.
      x.report(label) do
        verbose, $VERBOSE = $VERBOSE, nil
        begin
          iseq.eval
        ensure
          $VERBOSE = verbose
        end
      end
    end
  end

  def self.load_yaml(path)
    require "yaml"
    data = YAML.safe_load_file(path) || {}
    raise ArgumentError, "#{path}: expected a mapping" unless data.is_a?(Hash)

    scope = TOPLEVEL_BINDING.dup
    eval(data["prelude"], scope, path) if data["prelude"]

    entries = yaml_entries(path, data["benchmark"])
    raise ArgumentError, "#{path}: no benchmarks defined" if entries.empty?

    begin
      run do |x|
        entries.each do |name, script, prelude|
          entry_scope = scope.dup
          eval(prelude, entry_scope, path) if prelude
          x.report(name, yaml_loop(script, entry_scope))
        end
      end
    ensure
      eval(data["teardown"], scope, path) if data["teardown"]
    end
  end

  # A manual-loop action (takes the iteration count) closing over +scope+, so
  # the script can see the prelude's local variables.
  def self.yaml_loop(script, scope)
    eval("proc { |__n| __i = 0; while __i < __n\n#{script}\n__i += 1; end }", scope)
  end

  # Normalizes the supported forms of "benchmark:" to [name, script, prelude].
  def self.yaml_entries(path, spec)
    case spec
    when String
      [[spec.strip, spec, nil]]
    when Hash
      spec.map { |name, script| [name.to_s, script.to_s, nil] }
    when Array
      spec.map do |item|
        case item
        when String
          [item.strip, item, nil]
        when Hash
          script = item["script"] || item["name"]
          [(item["name"] || script).to_s, script.to_s, item["prelude"]]
        else
          raise ArgumentError, "#{path}: unsupported benchmark entry #{item.inspect}"
        end
      end
    when nil
      []
    else
      raise ArgumentError, "#{path}: unsupported benchmark definition #{spec.inspect}"
    end
  end
end
