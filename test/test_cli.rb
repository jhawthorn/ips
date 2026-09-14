# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

class TestCLI < Minitest::Test
  EXE = File.expand_path("../exe/ips", __dir__)
  LIB = File.expand_path("../lib", __dir__)

  def run_cli(*args, chdir: nil)
    opts = chdir ? { chdir: chdir } : {}
    Bundler.with_unbundled_env do
      out, status = Open3.capture2("ruby", "-I", LIB, EXE, *args, **opts)
      [out, status]
    end
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

  def test_prelude
    out, status = run_cli("--prelude", "ARY = [1, 2, 3]", "-e", "ARY.include?(2)", "-t", "0.3", "-w", "0.1")
    assert status.success?
    assert_match(/ARY\.include\?\(2\)/, out)
    assert_match(/i\/s/, out)
  end

  def test_require_and_load_path
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "mylib.rb"), "MYLIB = [1, 2, 3]\n")

      out, status = run_cli("-I", dir, "-r", "mylib", "-e", "MYLIB.include?(2)", "-t", "0.3", "-w", "0.1")
      assert status.success?
      assert_match(/MYLIB\.include\?\(2\)/, out)
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

  def test_sha_checks_out_commits_in_place
    in_git_repo do |dir|
      script = File.join(dir, "bench.rb")
      commit_bench(dir, script, "1 + 1")
      first = short_sha(dir, "HEAD")
      commit_bench(dir, script, "2 * 3")

      out, status = run_cli("--sha", first, script, chdir: dir)
      assert status.success?, out
      assert_match(/times faster than/, out)
      assert_match(/\bmain\b/, out)
      assert_match(/\b#{Regexp.escape(first)}\b/, out)

      # Left on the branch we started on, with its content restored.
      assert_equal "main", git(dir, "symbolic-ref", "--short", "HEAD").strip
      assert_includes File.read(script), "2 * 3"
    end
  end

  def test_sha_expands_ranges_oldest_first
    in_git_repo do |dir|
      script = File.join(dir, "bench.rb")
      4.times { |i| commit_bench(dir, script, "#{i} + 1") }
      shas = git(dir, "rev-list", "--reverse", "HEAD").split("\n")

      out, status = run_cli("-v", "--sha", "#{shas[0]}..#{shas[2]}", script, chdir: dir)
      assert status.success?, out
      # The current checkout runs first as the baseline (no checkout needed),
      # then the range's commits, oldest first. shas[0] is excluded by the range.
      checked_out = out.scan(/^git checkout --detach (\S+)$/).flatten
      assert_equal [shas[1], shas[2]], checked_out
      assert_equal "main", git(dir, "symbolic-ref", "--short", "HEAD").strip
    end
  end

  def test_sha_combines_with_ruby_label
    in_git_repo do |dir|
      script = File.join(dir, "bench.rb")
      commit_bench(dir, script, "1 + 1")
      first = short_sha(dir, "HEAD")
      commit_bench(dir, script, "2 * 3")

      out, status = run_cli("--ruby", RbConfig.ruby, "--sha", first, script, chdir: dir)
      assert status.success?, out
      assert_match(/ruby #{Regexp.escape(RbConfig.ruby)} @ main/, out)
      assert_match(/ruby #{Regexp.escape(RbConfig.ruby)} @ #{Regexp.escape(first)}/, out)
    end
  end

  def test_sha_aborts_on_dirty_working_tree
    in_git_repo do |dir|
      script = File.join(dir, "bench.rb")
      commit_bench(dir, script, "1 + 1")
      first = short_sha(dir, "HEAD")
      commit_bench(dir, script, "2 * 3")
      File.write(script, File.read(script) + "\n# dirty\n")

      out, err, status = Bundler.with_unbundled_env do
        Open3.capture3("ruby", "-I", LIB, EXE, "--sha", first, script, chdir: dir)
      end
      refute status.success?
      assert_match(/uncommitted changes/, err)
      assert_empty out
    end
  end

  private

  def commit_bench(dir, path, code)
    File.write(path, <<~RUBY)
      require "ips"
      IPS.run(time: 0.2, warmup: 0.05) do |x|
        x.report("work") { #{code} }
      end
    RUBY
    git(dir, "add", File.basename(path))
    git(dir, "commit", "-q", "-m", "bench #{code}")
  end

  def short_sha(dir, rev)
    git(dir, "rev-parse", "--short", rev).strip
  end

  def git(dir, *args)
    out, status = Open3.capture2("git", "-C", dir, *args)
    raise "git #{args.join(" ")} failed" unless status.success?
    out
  end

  def in_git_repo
    Dir.mktmpdir do |dir|
      dir = File.realpath(dir)
      git(dir, "init", "-q", "-b", "main")
      git(dir, "config", "user.email", "ips@example.com")
      git(dir, "config", "user.name", "IPS")
      yield dir
    end
  end
end
