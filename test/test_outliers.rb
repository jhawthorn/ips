# frozen_string_literal: true

require "test_helper"

class TestOutliers < Minitest::Test
  NS = IPS::Timing::NANOSECONDS_PER_SECOND

  def test_rare_stall_not_hidden
    # Simulates: 99 fast batches (1µs each) + 1 slow batch (1s)
    # benchmark-ips arithmetic mean of rates: ~99M i/s (hides the stall)
    # Our total_iter / wall_time: ~100 i/s (honest)
    cycles = 1
    fast_ns = 1_000         # 1µs
    slow_ns = NS            # 1s

    measurements = []
    t = 0
    99.times do
      measurements << [t, t + fast_ns]
      t += fast_ns
    end
    measurements << [t, t + slow_ns]

    result = IPS::Result.new("stall", cycles, measurements)

    # Arithmetic mean of per-batch rates would be:
    #   (99 * 1_000_000 + 1 * 1) / 100 ≈ 990_000 i/s
    arithmetic_mean = result.samples.sum / result.samples.size

    # Our ips uses total wall time:
    #   100 iterations / ~1.000099s ≈ 100 i/s
    assert arithmetic_mean > 900_000, "arithmetic mean of rates hides the stall"
    assert result.ips < 200, "total_iter/wall_time reveals the true throughput: #{result.ips}"
  end

  def test_periodic_stall
    # Every 100th iteration sleeps for 1s (the benchmark-ips footgun)
    cycles = 1
    fast_ns = 100           # ~100ns per iteration
    slow_ns = NS            # 1s

    measurements = []
    t = 0
    500.times do |i|
      duration = (i % 100 == 0) ? slow_ns : fast_ns
      measurements << [t, t + duration]
      t += duration
    end

    result = IPS::Result.new("periodic_stall", cycles, measurements)

    # 500 iterations in ~5s = ~100 i/s
    assert result.ips < 200
    assert result.ips > 50

    # Arithmetic mean would report millions
    arithmetic_mean = result.samples.sum / result.samples.size
    assert arithmetic_mean > 1_000_000
  end
end
