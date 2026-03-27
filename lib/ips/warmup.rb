# frozen_string_literal: true

module IPS
  class Warmup
    MAX_ITERATIONS = 1 << 30
    TARGET_BATCH_NS = 100_000_000
    MAX_WARMUP_CYCLES = 1000
    TARGET_WARMUP_CALLS = 1000

    def run(budget_ns)
      elapsed = 0

      # 1. Rough calibrate
      last_ns = yield 1
      elapsed += last_ns

      # 2. JIT warmup
      calls_remaining = TARGET_WARMUP_CALLS
      cycles = 1
      while elapsed < budget_ns && calls_remaining > 0
        remaining_ns = budget_ns - elapsed
        cycles = cycles_for(last_ns, cycles, remaining_ns / calls_remaining)
        cycles = MAX_WARMUP_CYCLES if cycles > MAX_WARMUP_CYCLES
        last_ns = yield cycles
        elapsed += last_ns
        calls_remaining -= 1
      end

      # 3. Calibrate to 100ms batches and run out the budget
      cycles = cycles_for(last_ns, cycles, TARGET_BATCH_NS)
      cycles = MAX_ITERATIONS if cycles > MAX_ITERATIONS
      while elapsed < budget_ns
        last_ns = yield cycles
        elapsed += last_ns
      end

      cycles
    end

    private

    def cycles_for(time_ns, iters, target_ns)
      c = (target_ns * iters) / time_ns
      c < 1 ? 1 : c
    end
  end
end
