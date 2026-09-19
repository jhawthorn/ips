# frozen_string_literal: true

require "test_helper"

class TestTiming < Minitest::Test
  NS = IPS::Timing::NANOSECONDS_PER_SECOND

  def test_now_returns_nanoseconds
    t = IPS::Timing.now
    assert_kind_of Integer, t
    assert t > 0
  end

  def test_now_is_monotonic
    t1 = IPS::Timing.now
    t2 = IPS::Timing.now
    assert t2 >= t1
  end

  def test_add_second
    t = 1_000_000_000
    result = IPS::Timing.add_second(t, 2)
    assert_equal 3_000_000_000, result
  end

  def test_add_second_fractional
    t = 0
    result = IPS::Timing.add_second(t, 0.5)
    assert_equal 500_000_000, result
  end
end
