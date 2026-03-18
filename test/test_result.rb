# frozen_string_literal: true

require "test_helper"

class TestResult < Minitest::Test
  NS = IPS::Timing::NANOSECONDS_PER_SECOND

  # Helper: flat times array with uniform batch duration, no gaps
  def make_times(count, batch_ns, start: 0)
    times = []
    t = start
    count.times do
      times << t << t + batch_ns
      t += batch_ns
    end
    times
  end

  def make_gc_times(count)
    Array.new(count * 2, 0)
  end

  def test_ips_simple
    # 10 batches of 1000 cycles, each taking exactly 100ms
    cycles = 1000
    batch_ns = NS / 10 # 100ms
    times = make_times(10, batch_ns)

    result = IPS::Result.new("test", cycles, times, make_gc_times(10))

    # 1000 cycles per 100ms = 10_000 i/s
    assert_equal 10_000, result.iterations
    assert_in_delta 10_000.0, result.ips, 0.01
  end

  def test_ips_with_gaps
    # 2 batches of 500 cycles, each taking 100ms, but with a 50ms gap between
    cycles = 500
    batch_ns = NS / 10 # 100ms
    gap_ns = NS / 20   # 50ms

    times = [
      0, batch_ns,
      batch_ns + gap_ns, 2 * batch_ns + gap_ns,
    ]

    result = IPS::Result.new("test", cycles, times, make_gc_times(2))

    # total wall time = 250ms, 1000 iterations
    assert_equal 1000, result.iterations
    assert_in_delta 4000.0, result.ips, 0.01 # 1000 / 0.25s
  end

  def test_overhead
    cycles = 100
    batch_ns = NS / 10 # 100ms
    gap_ns = NS / 100  # 10ms

    times = [
      0, batch_ns,
      batch_ns + gap_ns, 2 * batch_ns + gap_ns,
    ]

    result = IPS::Result.new("test", cycles, times, make_gc_times(2))

    assert_equal 2 * batch_ns, result.busy_ns
    assert_equal gap_ns, result.overhead_ns
    assert_equal 2 * batch_ns + gap_ns, result.total_ns
  end

  def test_gc_time
    cycles = 100
    batch_ns = NS / 10

    times = make_times(3, batch_ns)
    # Simulate 5ms GC in first batch, 0 in second, 10ms in third
    gc_times = [
      0, 5_000_000,
      5_000_000, 5_000_000,
      5_000_000, 15_000_000,
    ]

    result = IPS::Result.new("test", cycles, times, gc_times)

    assert_equal 15_000_000, result.gc_ns
  end

  def test_stddev_zero_when_uniform
    cycles = 1000
    batch_ns = NS / 10
    times = make_times(50, batch_ns)

    result = IPS::Result.new("test", cycles, times, make_gc_times(50))

    assert_in_delta 0.0, result.stddev, 0.01
    assert_in_delta 0.0, result.error_pct, 0.01
  end

  def test_stddev_nonzero_when_varied
    cycles = 1000
    # Alternate between 100ms and 200ms batches
    times = []
    t = 0
    10.times do |i|
      batch_ns = (i.even? ? NS / 10 : NS / 5)
      times << t << t + batch_ns
      t += batch_ns
    end

    result = IPS::Result.new("test", cycles, times, make_gc_times(10))

    assert result.stddev > 0
    assert result.error_pct > 0
  end

  def test_sample_count
    cycles = 100
    times = make_times(42, NS / 10)

    result = IPS::Result.new("test", cycles, times, make_gc_times(42))

    assert_equal 42, result.sample_count
  end

  def test_iterations
    cycles = 500
    times = make_times(20, NS / 10)

    result = IPS::Result.new("test", cycles, times, make_gc_times(20))

    assert_equal 10_000, result.iterations
  end
end
