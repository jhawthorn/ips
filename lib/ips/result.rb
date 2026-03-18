# frozen_string_literal: true

module IPS
  class Result
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
  end
end
