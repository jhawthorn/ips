# frozen_string_literal: true

module IPS
  class Warmup
    MAX_ITERATIONS = 1 << 30
    NANOSECONDS_PER_100MS = 100_000_000

    def run(budget_ns)
      elapsed_total = 0
      half = budget_ns / 2

      cycles = 1
      last_ns = 0
      loop do
        last_ns = yield cycles
        elapsed_total += last_ns
        break if cycles >= MAX_ITERATIONS
        break if elapsed_total + last_ns * 2 >= half
        cycles *= 2
      end

      cycles = cycles_per_100ms(last_ns, cycles)
      cycles = MAX_ITERATIONS if cycles > MAX_ITERATIONS

      while elapsed_total + NANOSECONDS_PER_100MS < budget_ns
        elapsed_ns = yield cycles
        elapsed_total += elapsed_ns
      end

      cycles
    end

    private

    def cycles_per_100ms(time_ns, iters)
      cycles = ((NANOSECONDS_PER_100MS.to_f / time_ns) * iters).to_i
      cycles <= 0 ? 1 : cycles
    end
  end
end
