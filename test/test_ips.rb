# frozen_string_literal: true

require "test_helper"

class TestIps < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::IPS::VERSION
  end

  def test_ips_alias
    assert_equal IPS, Ips
  end

  def test_report_single
    out, = capture_io do
      IPS.run(time: 0.1, warmup: 0.05) do |x|
        x.report("noop") { 1 + 1 }
      end
    end
    assert_match(/noop/, out)
    assert_match(/i\/s/, out)
  end

  def test_report_comparison
    out, = capture_io do
      IPS.run(time: 0.1, warmup: 0.05) do |x|
        x.report("fast") { 1 + 1 }
        x.report("slow") { sleep 0.001 }
      end
    end
    assert_match(/Summary/, out)
    assert_match(/times faster than/, out)
  end

  def test_report_with_manual_loop
    out, = capture_io do
      IPS.run(time: 0.1, warmup: 0.05) do |x|
        x.report("manual") { |n|
          i = 0
          while i < n
            _ = 1 + 1
            i += 1
          end
        }
      end
    end
    assert_match(/manual/, out)
    assert_match(/i\/s/, out)
  end
end
