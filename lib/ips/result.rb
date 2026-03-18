# frozen_string_literal: true

module IPS
  class Result
    attr_reader :label, :cycles, :iterations, :measurements

    def initialize(label, cycles, measurements)
      @label = label
      @cycles = cycles
      @measurements = measurements # array of [start_ns, end_ns]
      @iterations = measurements.size * cycles
    end

    # Total wall time from first batch start to last batch end
    def total_ns
      @measurements.last[1] - @measurements.first[0]
    end

    # Time spent actually running batches
    def busy_ns
      @measurements.sum { |t0, t1| t1 - t0 }
    end

    # Time between batches (measurement overhead, GC, scheduling)
    def overhead_ns
      total_ns - busy_ns
    end

    def ips
      Timing::NANOSECONDS_PER_SECOND * (@iterations.to_f / total_ns)
    end

    # Per-batch IPS samples for error estimation
    def samples
      @samples ||= @measurements.map { |t0, t1|
        Timing::NANOSECONDS_PER_SECOND * (@cycles.to_f / (t1 - t0))
      }
    end

    def sample_count
      @measurements.size
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
  end
end
