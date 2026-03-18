# frozen_string_literal: true

require "ips/job/entry"
require "ips/result"

module IPS
  class Job
    MAX_ITERATIONS = 1 << 30

    BAR_WIDTH = 30

    attr_accessor :warmup, :time

    def initialize(time: 5, warmup: 2)
      @list = []
      @time = time
      @warmup = warmup
      @timing = {}
      @tty = $stdout.tty?
    end

    def report(label, &block)
      @list.push Entry.new(label, block)
      self
    end

    def run
      max_label = @list.map { |e| e.label.size }.max
      max_label = 20 if max_label < 20
      @max_label = max_label

      results = @list.map do |item|
        @item_start = Timing.now
        @item_total_ns = ((@warmup + @time) * Timing::NANOSECONDS_PER_SECOND).to_i
        progress(item.label)
        warmup_item(item)
        result = measure_item(item)
        clear_progress
        print_result(result)
        result
      end

      print_summary(results)
    end

    private

    def progress(label, estimate: nil)
      return unless @tty
      elapsed_ns = Timing.now - @item_start
      fraction = (elapsed_ns.to_f / @item_total_ns).clamp(0.0, 1.0)
      filled = (fraction * BAR_WIDTH).to_i
      empty = BAR_WIDTH - filled
      remaining_ns = @item_total_ns - elapsed_ns
      remaining_s = remaining_ns > 0 ? (remaining_ns.to_f / Timing::NANOSECONDS_PER_SECOND).ceil : 0
      bar = "█" * filled + "░" * empty
      est = estimate ? "%10s i/s" % format_ips(estimate) : "              "
      $stdout.print "\r%#{@max_label}s: %s %s ETA %ds " % [label, est, bar, remaining_s]
      $stdout.flush
    end

    def clear_progress
      return unless @tty
      $stdout.print "\r\e[2K"
    end

    def cycles_per_100ms(time_ns, iters)
      cycles = ((Timing::NANOSECONDS_PER_100MS.to_f / time_ns) * iters).to_i
      cycles <= 0 ? 1 : cycles
    end

    def warmup_item(item)
      Timing.clean_env

      before = Timing.now
      target = Timing.add_second(before, @warmup / 2.0)

      cycles = 1
      begin
        t0 = Timing.now
        item.call_times(cycles)
        t1 = Timing.now
        warmup_iter = cycles
        warmup_ns = t1 - t0

        estimate = Timing::NANOSECONDS_PER_SECOND * (warmup_iter.to_f / warmup_ns)
        progress(item.label, estimate: estimate)

        break if cycles >= MAX_ITERATIONS
        cycles *= 2
      end while Timing.now + warmup_ns * 2 < target

      per_100ms = cycles_per_100ms(warmup_ns, warmup_iter)
      cycles = per_100ms > MAX_ITERATIONS ? MAX_ITERATIONS : per_100ms
      @timing[item] = cycles

      target = Timing.add_second(before, @warmup)
      while Timing.now + Timing::NANOSECONDS_PER_100MS < target
        t0 = Timing.now
        item.call_times(cycles)
        t1 = Timing.now
        estimate = Timing::NANOSECONDS_PER_SECOND * (cycles.to_f / (t1 - t0))
        progress(item.label, estimate: estimate)
      end
    end

    def measure_item(item)
      Timing.clean_env

      cycles = @timing[item]
      measurements = [] # [start_ns, end_ns] pairs
      iter = 0

      target = Timing.add_second(Timing.now, @time)

      begin
        t0 = Timing.now
        item.call_times(cycles)
        t1 = Timing.now

        elapsed_ns = t1 - t0
        next if elapsed_ns <= 0

        iter += cycles
        measurements << [t0, t1]

        total_ns = measurements.last[1] - measurements.first[0]
        progress(item.label, estimate: Timing::NANOSECONDS_PER_SECOND * (iter.to_f / total_ns))
      end while Timing.now < target

      Result.new(item.label, cycles, measurements)
    end

    def format_ips(ips)
      if ips >= 1_000_000_000
        "%.3fB" % (ips / 1_000_000_000.0)
      elsif ips >= 1_000_000
        "%.3fM" % (ips / 1_000_000.0)
      elsif ips >= 1_000
        "%.3fk" % (ips / 1_000.0)
      else
        "%.3f" % ips
      end
    end

    def print_result(r)
      $stdout.printf "%#{@max_label}s: %10s i/s (±%4.1f%%)\n",
        r.label, format_ips(r.ips), r.error_pct
    end

    def print_summary(results)
      return if results.size < 2

      sorted = results.sort_by { |r| -r.ips }
      best = sorted.first

      $stdout.puts "\nSummary"
      $stdout.puts "  #{best.label} ran"

      sorted[1..].each do |r|
        ratio = best.ips / r.ips
        ratio_error = ratio * Math.sqrt((best.stddev / best.ips)**2 + (r.stddev / r.ips)**2)
        $stdout.printf "    %.2f ± %.2f times faster than %s\n",
          ratio, ratio_error, r.label
      end
    end
  end
end
