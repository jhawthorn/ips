# frozen_string_literal: true

require "test_helper"
require "stringio"

class TestDisplay < Minitest::Test
  NS = IPS::Timing::NANOSECONDS_PER_SECOND

  def test_format_ips_billions
    assert_equal "1.000B", IPS::Display.format_ips(1_000_000_000)
    assert_equal "2.500B", IPS::Display.format_ips(2_500_000_000)
  end

  def test_format_ips_millions
    assert_equal "1.000M", IPS::Display.format_ips(1_000_000)
    assert_equal "42.500M", IPS::Display.format_ips(42_500_000)
  end

  def test_format_ips_thousands
    assert_equal "1.000k", IPS::Display.format_ips(1_000)
    assert_equal "99.999k", IPS::Display.format_ips(99_999)
  end

  def test_format_ips_small
    assert_equal "999.000", IPS::Display.format_ips(999)
    assert_equal "0.500", IPS::Display.format_ips(0.5)
  end

  def make_entry(label, cycles, count, batch_ns)
    times = []
    t = 0
    count.times do
      times << t << t + batch_ns
      t += batch_ns
    end
    gc_times = Array.new(count * 2, 0)
    IPS::Result::Entry.new(label, cycles, times, gc_times)
  end

  def test_compare_output
    fast = make_entry("fast", 1000, 10, NS / 100)  # 100k i/s
    slow = make_entry("slow", 1000, 10, NS / 10)    # 10k i/s

    out = StringIO.new
    IPS::Display.compare([["fast", fast], ["slow", slow]], out: out)

    output = out.string
    assert_match(/Summary/, output)
    assert_match(/fast ran/, output)
    assert_match(/times faster than slow/, output)
  end

  def test_compare_skips_single
    fast = make_entry("fast", 1000, 10, NS / 100)

    out = StringIO.new
    IPS::Display.compare([["fast", fast]], out: out)

    assert_empty out.string
  end

  def test_finish_item_output
    out = StringIO.new
    display = IPS::Display.new(["test_label"], out: out, debug: false)
    entry = make_entry("test_label", 1000, 10, NS / 10)

    # In non-tty mode the label is printed by start_item, not finish_item
    display.start_item("test_label", 5 * NS)
    display.finish_item(entry)

    output = out.string
    assert_match(/test_label/, output)
    assert_match(/i\/s/, output)
  end

  def test_finish_item_shows_gc_when_significant
    out = StringIO.new
    display = IPS::Display.new(["gctest"], out: out, debug: false)

    # Entry with significant GC: 50ms GC in 200ms total = 25%
    batch_ns = NS / 10
    times = [0, batch_ns, batch_ns, 2 * batch_ns]
    gc_times = [0, 50_000_000, 50_000_000, 50_000_000]
    entry = IPS::Result::Entry.new("gctest", 100, times, gc_times)

    display.finish_item(entry)

    assert_match(/GC/, out.string)
  end

  def test_finish_item_hides_gc_when_small
    out = StringIO.new
    display = IPS::Display.new(["nogc"], out: out, debug: false)
    entry = make_entry("nogc", 1000, 10, NS / 10)

    display.finish_item(entry)

    refute_match(/GC/, out.string)
  end

  def test_summary_skips_single_entry
    out = StringIO.new
    display = IPS::Display.new(["only"], out: out, debug: false)
    entry = make_entry("only", 1000, 10, NS / 10)

    display.summary([entry])

    assert_empty out.string
  end

  class FakeTTY < StringIO
    def initialize(cols)
      super(+"")
      @cols = cols
    end

    def tty?
      true
    end

    def winsize
      [24, @cols]
    end
  end

  def test_progress_disabled_on_narrow_terminal
    out = FakeTTY.new(40)
    display = IPS::Display.new(["test"], out: out)

    display.start_item("test", 5 * NS)

    # Falls back to the non-tty label prefix, with no progress bar or ETA
    refute_match(/[█░]/, out.string)
    refute_match(/ETA/, out.string)
  end

  def test_progress_enabled_on_wide_terminal
    out = FakeTTY.new(200)
    display = IPS::Display.new(["test"], out: out)

    display.start_item("test", 5 * NS)

    refute_empty out.string
  end
end
