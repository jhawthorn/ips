# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

class TestCLI < Minitest::Test
  EXE = File.expand_path("../exe/ips", __dir__)
  LIB = File.expand_path("../lib", __dir__)

  def run_cli(*args)
    out, status = Open3.capture2("ruby", "-I", LIB, EXE, *args)
    [out, status]
  end

  def test_inline_single_run
    out, status = run_cli("-e", "Object.allocate", "-e", "Object.new", "-t", "0.5", "-w", "0.1")
    assert status.success?
    assert_match(/i\/s/, out)
    assert_match(/Summary/, out)
    assert_match(/times faster than/, out)
  end

  def test_script_mode
    Dir.mktmpdir do |dir|
      script = File.join(dir, "bench.rb")
      File.write(script, <<~RUBY)
        require "ips"
        IPS.run(time: 0.5, warmup: 0.1) do |x|
          x.report("add") { 1 + 1 }
          x.report("mul") { 2 * 3 }
        end
      RUBY

      out, status = run_cli(script)
      assert status.success?
      assert_match(/add/, out)
      assert_match(/mul/, out)
      assert_match(/i\/s/, out)
    end
  end

  def test_runs_aggregates
    out, status = run_cli("--runs", "2", "-e", "Object.allocate", "-e", "Object.new", "-t", "0.5", "-w", "0.1")
    assert status.success?
    # Per-run summaries suppressed; one aggregate summary at the end
    assert_equal 1, out.scan(/Summary/).size
    assert_match(/Aggregate \(2 runs\)/, out)
    assert_match(/Object\.allocate/, out)
    assert_match(/Object\.new/, out)
    assert_match(/times faster than/, out)
  end

  def test_runs_with_multiple_rubies
    ruby = RbConfig.ruby
    Dir.mktmpdir do |dir|
      script = File.join(dir, "bench.rb")
      File.write(script, <<~RUBY)
        require "ips"
        IPS.run(time: 0.5, warmup: 0.1) do |x|
          x.report("add") { 1 + 1 }
          x.report("mul") { 2 * 3 }
        end
      RUBY

      out, status = run_cli("--ruby", ruby, "--ruby", ruby, "--runs", "2", script)
      assert status.success?
      assert_match(/Aggregate \(4 runs\)/, out)
      assert_match(/add/, out)
      assert_match(/mul/, out)
      assert_match(/times faster than/, out)
    end
  end
end
