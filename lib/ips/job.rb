# frozen_string_literal: true

require "ips/job/entry"
require "ips/result"
require "ips/display"

module IPS
  class Job
    MAX_ITERATIONS = 1 << 30

    attr_accessor :warmup, :time

    def initialize(time: 5, warmup: time * 0.2, summary: true, out: $stdout)
      @list = []
      @time = time
      @warmup = warmup
      @summary = summary
      @timing = {}
      @out = out
    end

    def report(label, action = nil, &block)
      raise ArgumentError, "cannot specify both action and block" if action && block
      action ||= block || label
      @list.push Entry.new(label, action)
      self
    end

    def run
      display = Display.new(@list.map(&:label), out: @out)
      total_ns = ((@warmup + @time) * Timing::NANOSECONDS_PER_SECOND).to_i

      results = @list.map do |item|
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

    def cycles_per_100ms(time_ns, iters)
      cycles = ((Timing::NANOSECONDS_PER_100MS.to_f / time_ns) * iters).to_i
      cycles <= 0 ? 1 : cycles
    end

    def warmup_item(item, display)
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
        display.progress(estimate: estimate)

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
        display.progress(estimate: estimate)
      end
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

        total_ns = t1 - times[0]
        display.progress(estimate: Timing::NANOSECONDS_PER_SECOND * (iter.to_f / total_ns))
      end while Timing.now < target

      Result::Entry.new(item.label, cycles, times, gc_times)
    end
  end
end
