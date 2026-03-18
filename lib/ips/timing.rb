# frozen_string_literal: true

module IPS
  module Timing
    MICROSECONDS_PER_SECOND = 1_000_000

    def self.now
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_microsecond)
    end

    def self.time_us(before, after)
      after - before
    end

    def self.add_second(t, s)
      t + (s * MICROSECONDS_PER_SECOND)
    end

    def self.clean_env
      GC.start
    end
  end
end
