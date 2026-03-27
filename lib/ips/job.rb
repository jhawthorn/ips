# frozen_string_literal: true

require "ips/job/entry"
require "ips/result"
require "ips/display"
require "ips/warmup"

module IPS
  class Job
    attr_accessor :warmup, :time

    def initialize(time: 5, warmup: time * 0.2, summary: true, debug: false, frozen_string_literal: true, out: $stdout)
      @list = []
      @time = time
      @warmup = warmup
      @summary = summary
      @debug = debug
      @frozen_string_literal = frozen_string_literal
      @timing = {}
      @out = out
    end

    def report(label, action = nil, &block)
      raise ArgumentError, "cannot specify both action and block" if action && block
      action ||= block || label
      @list.push Entry.new(label, action, frozen_string_literal: @frozen_string_literal)
      self
    end

    def run
      display = Display.new(@list.map(&:label), out: @out, debug: @debug)
      total_ns = ((@warmup + @time) * Timing::NANOSECONDS_PER_SECOND).to_i

      results = @list.map do |item|
        if @debug
          source = item.source
          @out.puts "--- #{item.label} ---"
          @out.puts source if source
          @out.puts
        end
        display.start_item(item.label, total_ns)
        warmup_item(item, display)
        result = measure_item(item, display)
        display.finish_item(result)
        result
      end

      display.summary(results) if @summary
      Result.build(results)
    end

    private

    def warmup_item(item, display)
      Timing.clean_env

      budget_ns = (@warmup * Timing::NANOSECONDS_PER_SECOND).to_i
      warmup = Warmup.new
      last_progress = 0
      cycles = warmup.run(budget_ns) do |iters|
        t0 = Timing.now
        item.call_times(iters)
        t1 = Timing.now
        elapsed_ns = t1 - t0
        if t1 - last_progress > Timing::NANOSECONDS_PER_100MS
          estimate = Timing::NANOSECONDS_PER_SECOND * (iters.to_f / elapsed_ns)
          display.progress(estimate: estimate)
          last_progress = t1
        end
        @out.printf "  warmup: %d cycles in %dns (%s i/s)\n",
          iters, elapsed_ns, Display.format_ips(Timing::NANOSECONDS_PER_SECOND * (iters.to_f / elapsed_ns)) if @debug
        elapsed_ns
      end

      @timing[item] = cycles
      @out.puts "  cycles: #{cycles}" if @debug
    end

    def measure_item(item, display)
      Timing.clean_env

      cycles = @timing[item]
      times = []  # flat: [start0, end0, start1, end1, ...]
      gc_times = [] # flat: [gc_before0, gc_after0, ...]
      iter = 0

      target = Timing.add_second(Timing.now, @time)

      begin
        gc0 = GC.total_time
        t0 = Timing.now
        item.call_times(cycles)
        t1 = Timing.now
        gc1 = GC.total_time

        elapsed_ns = t1 - t0
        next if elapsed_ns <= 0

        iter += cycles
        times << t0 << t1
        gc_times << gc0 << gc1

        if @debug
          batch_ips = Timing::NANOSECONDS_PER_SECOND * (cycles.to_f / elapsed_ns)
          gc_ns = gc1 - gc0
          @out.printf "  batch: %.3fms  ips: %s  gc: %.3fms\n",
            elapsed_ns / 1_000_000.0, Display.format_ips(batch_ips), gc_ns / 1_000_000.0
        end

        total_ns = t1 - times[0]
        display.progress(estimate: Timing::NANOSECONDS_PER_SECOND * (iter.to_f / total_ns))
      end while Timing.now < target

      Result::Entry.new(item.label, cycles, times, gc_times)
    end
  end
end
