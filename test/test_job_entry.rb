# frozen_string_literal: true

require "test_helper"

class TestJobEntry < Minitest::Test
  def test_block_action
    entry = IPS::Job::Entry.new("block", proc { 1 + 1 }, frozen_string_literal: true)

    assert_equal "block", entry.label
    assert_nil entry.source
    entry.call_times(100) # should not raise
  end

  def test_string_action
    entry = IPS::Job::Entry.new("string", "(1 + 1).to_s", frozen_string_literal: true)

    assert_equal "string", entry.label
    assert_includes entry.source, "call_times"
    entry.call_times(100) # should not raise
  end

  def test_manual_loop_action
    count = 0
    entry = IPS::Job::Entry.new("manual", proc { |n| count += n }, frozen_string_literal: true)

    entry.call_times(42)
    assert_equal 42, count
  end

  def test_string_action_respects_frozen_string_literal
    entry = IPS::Job::Entry.new("frozen", "'hello'.frozen?", frozen_string_literal: true)

    # The compiled method should work with frozen string literals
    entry.call_times(1) # should not raise
  end

  def test_report_raises_with_both_action_and_block
    assert_raises(ArgumentError) do
      IPS::Job.new(time: 0.1, warmup: 0.05).report("x", "1+1") { 1 + 1 }
    end
  end
end
