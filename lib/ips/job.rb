# frozen_string_literal: true

require_relative "job/entry"

module IPS
  class Job
    MICROSECONDS_PER_100MS = 100_000
    MAX_ITERATIONS = 1 << 30

    SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏]

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
      @spinner_idx = 0

      results = @list.map do |item|
        spin(item.label)
        warmup_item(item)
        result = measure_item(item)
        clear_spin
        print_result(result)
        result
      end

      print_summary(results)
    end

    private

    def spin(label)
      return unless @tty
      s = SPINNER[@spinner_idx % SPINNER.size]
      @spinner_idx += 1
      $stdout.print "\r%#{@max_label}s: %s " % [label, s]
      $stdout.flush
      @spinning = true
    end

    def clear_spin
      return unless @tty && @spinning
      $stdout.print "\r\e[2K"
      @spinning = false
    end

    def cycles_per_100ms(time_us, iters)
      cycles = ((MICROSECONDS_PER_100MS / time_us) * iters).to_i
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
        warmup_time_us = Timing.time_us(t0, t1)

        spin(item.label)

        break if cycles >= MAX_ITERATIONS
        cycles *= 2
      end while Timing.now + warmup_time_us * 2 < target

      per_100ms = cycles_per_100ms(warmup_time_us, warmup_iter)
      cycles = per_100ms > MAX_ITERATIONS ? MAX_ITERATIONS : per_100ms
      @timing[item] = cycles

      target = Timing.add_second(before, @warmup)
      while Timing.now + MICROSECONDS_PER_100MS < target
        item.call_times(cycles)
        spin(item.label)
      end
    end

    def measure_item(item)
      Timing.clean_env

      cycles = @timing[item]
      measurements_us = []
      iter = 0

      target = Timing.add_second(Timing.now, @time)

      begin
        before = Timing.now
        item.call_times(cycles)
        after = Timing.now

        iter_us = Timing.time_us(before, after)
        next if iter_us <= 0.0

        iter += cycles
        measurements_us << iter_us

        spin(item.label)
      end while Timing.now < target

      samples = measurements_us.map { |t| Timing::MICROSECONDS_PER_SECOND * (cycles.to_f / t) }

      mean = samples.sum / samples.size
      variance = samples.sum { |s| (s - mean) ** 2 } / samples.size
      stddev = Math.sqrt(variance)
      error_pct = (stddev / mean) * 100.0

      {
        label: item.label,
        ips: mean,
        stddev: stddev,
        error_pct: error_pct,
        iterations: iter,
        samples: samples.size,
      }
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
        r[:label], format_ips(r[:ips]), r[:error_pct]
    end

    def print_summary(results)
      return if results.size < 2

      sorted = results.sort_by { |r| -r[:ips] }
      best = sorted.first

      $stdout.puts "\nSummary"
      $stdout.puts "  #{best[:label]} ran"

      sorted[1..].each do |r|
        ratio = best[:ips] / r[:ips]
        ratio_error = ratio * Math.sqrt((best[:stddev] / best[:ips])**2 + (r[:stddev] / r[:ips])**2)
        $stdout.printf "    %.2f ± %.2f times faster than %s\n",
          ratio, ratio_error, r[:label]
      end
    end
  end
end
