# frozen_string_literal: true

require "test_helper"

class TestResult < Minitest::Test
  NS = IPS::Timing::NANOSECONDS_PER_SECOND

  # Helper: build measurements with uniform batch duration, no gaps
  def make_measurements(count, batch_ns, start: 0)
    count.times.map do |i|
      t0 = start + i * batch_ns
      [t0, t0 + batch_ns]
    end
  end

  def test_ips_simple
    # 10 batches of 1000 cycles, each taking exactly 100ms
    cycles = 1000
    batch_ns = NS / 10 # 100ms
    measurements = make_measurements(10, batch_ns)

    result = IPS::Result.new("test", cycles, measurements)

    # 1000 cycles per 100ms = 10_000 i/s
    assert_equal 10_000, result.iterations
    assert_in_delta 10_000.0, result.ips, 0.01
  end

  def test_ips_with_gaps
    # 2 batches of 500 cycles, each taking 100ms, but with a 50ms gap between
    cycles = 500
    batch_ns = NS / 10 # 100ms
    gap_ns = NS / 20   # 50ms

    measurements = [
      [0, batch_ns],
      [batch_ns + gap_ns, 2 * batch_ns + gap_ns],
    ]

    result = IPS::Result.new("test", cycles, measurements)

    # total wall time = 250ms, 1000 iterations
    assert_equal 1000, result.iterations
    assert_in_delta 4000.0, result.ips, 0.01 # 1000 / 0.25s
  end

  def test_overhead
    cycles = 100
    batch_ns = NS / 10 # 100ms
    gap_ns = NS / 100  # 10ms

    measurements = [
      [0, batch_ns],
      [batch_ns + gap_ns, 2 * batch_ns + gap_ns],
    ]

    result = IPS::Result.new("test", cycles, measurements)

    assert_equal 2 * batch_ns, result.busy_ns
    assert_equal gap_ns, result.overhead_ns
    assert_equal 2 * batch_ns + gap_ns, result.total_ns
  end

  def test_stddev_zero_when_uniform
    cycles = 1000
    batch_ns = NS / 10
    measurements = make_measurements(50, batch_ns)

    result = IPS::Result.new("test", cycles, measurements)

    assert_in_delta 0.0, result.stddev, 0.01
    assert_in_delta 0.0, result.error_pct, 0.01
  end

  def test_stddev_nonzero_when_varied
    cycles = 1000
    # Alternate between 100ms and 200ms batches
    measurements = 10.times.map do |i|
      batch_ns = (i.even? ? NS / 10 : NS / 5)
      t0 = i * NS / 5 # doesn't matter, just need start < end
      [t0, t0 + batch_ns]
    end

    result = IPS::Result.new("test", cycles, measurements)

    assert result.stddev > 0
    assert result.error_pct > 0
  end

  def test_sample_count
    cycles = 100
    measurements = make_measurements(42, NS / 10)

    result = IPS::Result.new("test", cycles, measurements)

    assert_equal 42, result.sample_count
  end

  def test_iterations
    cycles = 500
    measurements = make_measurements(20, NS / 10)

    result = IPS::Result.new("test", cycles, measurements)

    assert_equal 10_000, result.iterations
  end
end
