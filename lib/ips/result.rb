# frozen_string_literal: true

module IPS
  class Result
    attr_accessor :uuid, :run_label, :ruby_version, :ruby_description, :ruby_executable, :pid, :yjit_enabled, :entries

    def initialize(entries, uuid:, ruby_version:, ruby_description:, ruby_executable:, pid:, yjit_enabled:)
      @entries = entries
      @uuid = uuid
      @ruby_version = ruby_version
      @ruby_description = ruby_description
      @ruby_executable = ruby_executable
      @pid = pid
      @yjit_enabled = yjit_enabled
    end

    def self.build(entries)
      new(entries,
        uuid: generate_uuid,
        ruby_version: RUBY_VERSION,
        ruby_description: RUBY_DESCRIPTION,
        ruby_executable: nil,
        pid: Process.pid,
        yjit_enabled: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?)
    end

    def self.generate_uuid
      random = Random.urandom(16)
      bytes = random.unpack("NnnnnN")
      bytes[2] = (bytes[2] & 0x0fff) | 0x4000
      bytes[3] = (bytes[3] & 0x3fff) | 0x8000
      "%08x-%04x-%04x-%04x-%04x%08x" % bytes
    end

    def to_h
      {
        "uuid" => @uuid,
        "ruby_version" => @ruby_version,
        "ruby_description" => @ruby_description,
        "ruby_executable" => @ruby_executable,
        "pid" => @pid,
        "yjit_enabled" => @yjit_enabled,
        "results" => @entries.map(&:to_h)
      }
    end

    def self.from_h(hash)
      entries = hash["results"].map { |h| Entry.from_h(h) }
      new(entries,
        uuid: hash["uuid"],
        ruby_version: hash["ruby_version"],
        ruby_description: hash["ruby_description"],
        ruby_executable: hash["ruby_executable"],
        pid: hash["pid"],
        yjit_enabled: hash["yjit_enabled"])
    end

    def self.save!(path, results)
      require "json"

      data = if File.exist?(path)
        JSON.parse(File.read(path))
      else
        { "runs" => [] }
      end

      Array(results).each do |result|
        data["runs"] << result.to_h
      end

      File.write(path, JSON.pretty_generate(data) + "\n")
    end

    def self.load(path)
      require "json"
      data = JSON.parse(File.read(path))
      data["runs"].map { |h| from_h(h) }
    end

    def self.compare_aggregate(results, out: $stdout)
      grouped = group_entries(results)
      pairs = grouped.map do |label, entries|
        [label, Entry::Aggregate.new(entries)]
      end
      Display.compare(pairs, out: out)
    end

    def self.group_entries(results)
      num_entries = results.first.entries.size
      num_entries.times.map do |i|
        entries = results.map { |r| r.entries[i] }
        [entries.first.label, entries]
      end
    end

    def self.compare(results, out: $stdout)
      return if results.size < 2

      run_labels = distinguish(results)
      one_entry = results.all? { |r| r.entries.size == 1 }

      pairs = results.flat_map { |r|
        r.entries.map { |e|
          label = one_entry ? run_labels[r.uuid] : "#{e.label} (#{run_labels[r.uuid]})"
          [label, e]
        }
      }

      Display.compare(pairs, out: out)
    end

    def self.distinguish(results)
      [:run_label, :ruby_version, :ruby_description, :ruby_executable, :uuid].each do |field|
        values = results.map { |r| r.send(field) }
        next if values.any?(&:nil?)
        if values.uniq.size == results.size
          return results.each_with_object({}) { |r, h| h[r.uuid] = r.send(field).to_s }
        end
      end
    end

    class Entry
      attr_reader :label, :cycles, :times, :gc_times

      # times: flat array [start0, end0, start1, end1, ...]
      # gc_times: flat array [gc_before0, gc_after0, gc_before1, gc_after1, ...]
      def initialize(label, cycles, times, gc_times)
        @label = label
        @cycles = cycles
        @times = times
        @gc_times = gc_times
      end

      def sample_count
        @times.size / 2
      end

      def iterations
        sample_count * @cycles
      end

      # Total wall time from first batch start to last batch end
      def total_ns
        @times[-1] - @times[0]
      end

      # Time spent actually running batches
      def busy_ns
        total = 0
        i = 0
        while i < @times.size
          total += @times[i + 1] - @times[i]
          i += 2
        end
        total
      end

      # Time between batches (measurement overhead, GC, scheduling)
      def overhead_ns
        total_ns - busy_ns
      end

      # Total GC time during measurement
      def gc_ns
        total = 0
        i = 0
        while i < @gc_times.size
          total += @gc_times[i + 1] - @gc_times[i]
          i += 2
        end
        total
      end

      def ips
        Timing::NANOSECONDS_PER_SECOND * (iterations.to_f / total_ns)
      end

      # Per-batch IPS samples for error estimation
      def samples
        @samples ||= begin
          s = Array.new(sample_count)
          i = 0
          while i < @times.size
            s[i / 2] = Timing::NANOSECONDS_PER_SECOND * (@cycles.to_f / (@times[i + 1] - @times[i]))
            i += 2
          end
          s
        end
      end

      def sample_mean
        @sample_mean ||= samples.sum / samples.size
      end

      def stddev
        variance = samples.sum { |s| (s - sample_mean) ** 2 } / samples.size
        Math.sqrt(variance)
      end

      def error_pct
        (stddev / ips) * 100.0
      end

      def gc_pct
        total = total_ns
        total > 0 ? (gc_ns.to_f / total) * 100.0 : 0.0
      end

      def to_h
        {
          "label" => @label,
          "cycles" => @cycles,
          "times" => @times,
          "gc_times" => @gc_times
        }
      end

      def self.from_h(hash)
        new(hash["label"], hash["cycles"], hash["times"], hash["gc_times"])
      end

      class Aggregate
        attr_reader :entries

        def initialize(entries)
          @entries = entries
        end

        def ips
          ips_values = @entries.map(&:ips)
          ips_values.sum / ips_values.size
        end

        def stddev
          mean = ips
          variance = @entries.map(&:ips).sum { |v| (v - mean) ** 2 } / @entries.size
          Math.sqrt(variance)
        end
      end
    end
  end
end
