# frozen_string_literal: true

require "test_helper"
require "stringio"

class TestIps < Minitest::Test
  def setup
    IPS.results.clear
  end

  def test_that_it_has_a_version_number
    refute_nil ::IPS::VERSION
  end

  def test_ips_alias
    assert_equal IPS, Ips
  end

  def test_report_single
    out = StringIO.new
    IPS.run(time: 0.1, warmup: 0.05, out: out) do |x|
      x.report("noop") { 1 + 1 }
    end
    assert_match(/noop/, out.string)
    assert_match(/i\/s/, out.string)
  end

  def test_report_comparison
    out = StringIO.new
    IPS.run(time: 0.1, warmup: 0.05, out: out) do |x|
      x.report("fast") { 1 + 1 }
      x.report("slow") { sleep 0.001 }
    end
    assert_match(/Summary/, out.string)
    assert_match(/times faster than/, out.string)
  end

  def test_results_accumulates
    IPS.run(time: 0.1, warmup: 0.05, out: StringIO.new) do |x|
      x.report("a") { 1 + 1 }
    end
    IPS.run(time: 0.1, warmup: 0.05, out: StringIO.new) do |x|
      x.report("b") { 2 * 3 }
    end
    assert_equal 2, IPS.results.size
    assert_equal "a", IPS.results[0].entries.first.label
    assert_equal "b", IPS.results[1].entries.first.label
  end

  def test_report_with_manual_loop
    out = StringIO.new
    IPS.run(time: 0.1, warmup: 0.05, out: out) do |x|
      x.report("manual") { |n|
        i = 0
        while i < n
          _ = 1 + 1
          i += 1
        end
      }
    end
    assert_match(/manual/, out.string)
    assert_match(/i\/s/, out.string)
  end
end
