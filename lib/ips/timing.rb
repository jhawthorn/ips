# frozen_string_literal: true

module IPS
  module Timing
    NANOSECONDS_PER_SECOND = 1_000_000_000
    NANOSECONDS_PER_100MS = 100_000_000

    def self.now
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    end

    def self.add_second(t, s)
      t + (s * NANOSECONDS_PER_SECOND).to_i
    end

    def self.clean_env
      GC.start
    end
  end
end
