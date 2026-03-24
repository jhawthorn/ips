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

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(10))

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

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(2))

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

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(2))

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

    result = IPS::Result::Entry.new("test", cycles, times, gc_times)

    assert_equal 15_000_000, result.gc_ns
  end

  def test_stddev_zero_when_uniform
    cycles = 1000
    batch_ns = NS / 10
    times = make_times(50, batch_ns)

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(50))

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

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(10))

    assert result.stddev > 0
    assert result.error_pct > 0
  end

  def test_sample_count
    cycles = 100
    times = make_times(42, NS / 10)

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(42))

    assert_equal 42, result.sample_count
  end

  def test_iterations
    cycles = 500
    times = make_times(20, NS / 10)

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(20))

    assert_equal 10_000, result.iterations
  end

  def test_gc_pct
    cycles = 100
    batch_ns = NS / 10
    times = make_times(2, batch_ns)
    # 10ms GC out of 200ms total = 5%
    gc_times = [0, 10_000_000, 10_000_000, 10_000_000]

    result = IPS::Result::Entry.new("test", cycles, times, gc_times)

    assert_in_delta 5.0, result.gc_pct, 0.01
  end

  def test_gc_pct_zero_when_no_gc
    cycles = 100
    times = make_times(5, NS / 10)

    result = IPS::Result::Entry.new("test", cycles, times, make_gc_times(5))

    assert_in_delta 0.0, result.gc_pct, 0.01
  end

  def test_entry_to_h
    entry = IPS::Result::Entry.new("foo", 42, [0, 100, 200, 300], [0, 5, 5, 10])

    h = entry.to_h

    assert_equal "foo", h["label"]
    assert_equal 42, h["cycles"]
    assert_equal [0, 100, 200, 300], h["times"]
    assert_equal [0, 5, 5, 10], h["gc_times"]
  end

  def test_entry_from_h
    h = { "label" => "bar", "cycles" => 99, "times" => [0, 500, 600, 1100], "gc_times" => [0, 0, 0, 0] }

    entry = IPS::Result::Entry.from_h(h)

    assert_equal "bar", entry.label
    assert_equal 99, entry.cycles
    assert_equal [0, 500, 600, 1100], entry.times
    assert_equal 2, entry.sample_count
  end

  def test_entry_round_trip
    original = IPS::Result::Entry.new("rt", 200, make_times(5, NS / 10), make_gc_times(5))

    restored = IPS::Result::Entry.from_h(original.to_h)

    assert_equal original.label, restored.label
    assert_equal original.cycles, restored.cycles
    assert_equal original.times, restored.times
    assert_equal original.gc_times, restored.gc_times
    assert_in_delta original.ips, restored.ips, 0.01
  end

  def test_result_to_h_and_from_h
    entries = [IPS::Result::Entry.new("a", 100, make_times(3, NS / 10), make_gc_times(3))]
    result = IPS::Result.new(entries,
      uuid: "test-uuid-1234",
      ruby_version: "3.4.0",
      ruby_description: "ruby 3.4.0",
      ruby_executable: "/usr/bin/ruby",
      pid: 12345,
      yjit_enabled: true)

    h = result.to_h
    restored = IPS::Result.from_h(h)

    assert_equal "test-uuid-1234", restored.uuid
    assert_equal "3.4.0", restored.ruby_version
    assert_equal "ruby 3.4.0", restored.ruby_description
    assert_equal "/usr/bin/ruby", restored.ruby_executable
    assert_equal 12345, restored.pid
    assert_equal true, restored.yjit_enabled
    assert_equal 1, restored.entries.size
    assert_equal "a", restored.entries.first.label
  end

  def test_result_save_and_load
    require "tmpdir"

    entries = [IPS::Result::Entry.new("x", 50, make_times(2, NS / 10), make_gc_times(2))]
    result = IPS::Result.new(entries,
      uuid: "save-test",
      ruby_version: "3.4.0",
      ruby_description: "ruby 3.4.0",
      ruby_executable: nil,
      pid: 1,
      yjit_enabled: false)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "results.json")
      IPS::Result.save!(path, result)
      loaded = IPS::Result.load(path)

      assert_equal 1, loaded.size
      assert_equal "save-test", loaded.first.uuid
      assert_equal "x", loaded.first.entries.first.label

      # Save a second result to the same file
      entries2 = [IPS::Result::Entry.new("y", 60, make_times(3, NS / 10), make_gc_times(3))]
      result2 = IPS::Result.new(entries2,
        uuid: "save-test-2",
        ruby_version: "3.4.0",
        ruby_description: "ruby 3.4.0",
        ruby_executable: nil,
        pid: 2,
        yjit_enabled: false)

      IPS::Result.save!(path, result2)
      loaded = IPS::Result.load(path)

      assert_equal 2, loaded.size
      assert_equal "save-test-2", loaded.last.uuid
    end
  end

  def test_generate_uuid_format
    uuid = IPS::Result.generate_uuid

    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, uuid)
  end

  def test_generate_uuid_unique
    uuids = 10.times.map { IPS::Result.generate_uuid }

    assert_equal 10, uuids.uniq.size
  end

  def test_result_build
    entries = [IPS::Result::Entry.new("b", 100, make_times(2, NS / 10), make_gc_times(2))]
    result = IPS::Result.build(entries)

    assert_match(/\A[0-9a-f]{8}-/, result.uuid)
    assert_equal RUBY_VERSION, result.ruby_version
    assert_equal RUBY_DESCRIPTION, result.ruby_description
    assert_equal Process.pid, result.pid
    assert_equal 1, result.entries.size
  end

  def test_distinguish_by_ruby_version
    e = [IPS::Result::Entry.new("a", 100, make_times(2, NS / 10), make_gc_times(2))]
    r1 = IPS::Result.new(e, uuid: "u1", ruby_version: "3.3.0", ruby_description: "ruby 3.3.0", ruby_executable: nil, pid: 1, yjit_enabled: false)
    r2 = IPS::Result.new(e, uuid: "u2", ruby_version: "3.4.0", ruby_description: "ruby 3.4.0", ruby_executable: nil, pid: 1, yjit_enabled: false)

    labels = IPS::Result.distinguish([r1, r2])

    assert_equal "3.3.0", labels["u1"]
    assert_equal "3.4.0", labels["u2"]
  end

  def test_distinguish_falls_back_to_uuid
    e = [IPS::Result::Entry.new("a", 100, make_times(2, NS / 10), make_gc_times(2))]
    r1 = IPS::Result.new(e, uuid: "aaa", ruby_version: "3.4.0", ruby_description: "ruby 3.4.0", ruby_executable: nil, pid: 1, yjit_enabled: false)
    r2 = IPS::Result.new(e, uuid: "bbb", ruby_version: "3.4.0", ruby_description: "ruby 3.4.0", ruby_executable: nil, pid: 1, yjit_enabled: false)

    labels = IPS::Result.distinguish([r1, r2])

    assert_equal "aaa", labels["aaa"]
    assert_equal "bbb", labels["bbb"]
  end

  def test_distinguish_prefers_run_label
    e = [IPS::Result::Entry.new("a", 100, make_times(2, NS / 10), make_gc_times(2))]
    r1 = IPS::Result.new(e, uuid: "u1", ruby_version: "3.4.0", ruby_description: "ruby 3.4.0", ruby_executable: nil, pid: 1, yjit_enabled: false)
    r1.run_label = "before"
    r2 = IPS::Result.new(e, uuid: "u2", ruby_version: "3.4.0", ruby_description: "ruby 3.4.0", ruby_executable: nil, pid: 1, yjit_enabled: false)
    r2.run_label = "after"

    labels = IPS::Result.distinguish([r1, r2])

    assert_equal "before", labels["u1"]
    assert_equal "after", labels["u2"]
  end
end
