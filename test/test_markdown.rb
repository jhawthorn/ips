# frozen_string_literal: true

require "test_helper"
require "ips/markdown"

class TestMarkdown < Minitest::Test
  NS = IPS::Timing::NANOSECONDS_PER_SECOND

  # An entry running at +ips+ with per-batch jitter of +jitter+ (fraction).
  def entry(label, ips, jitter: 0.0, count: 10)
    cycles = 1000
    times = []
    t = 0
    count.times do |i|
      rate = ips * (1 + (i.even? ? jitter : -jitter))
      batch = (cycles * NS / rate).round
      times << t << t + batch
      t += batch
    end
    IPS::Result::Entry.new(label, cycles, times, Array.new(count * 2, 0))
  end

  def result(*entries, description: "ruby 4.0.0")
    IPS::Result.new(entries, uuid: "u", ruby_version: "4.0.0", ruby_description: description,
      ruby_executable: nil, pid: 1, yjit_enabled: false)
  end

  def table_rows(md)
    md.lines.grep(/\A\|/).map { |l| l.chomp.split(/(?<!\\)\|/)[1..].map(&:strip) }
  end

  def test_single_variant_compares_against_fastest
    md = IPS::Markdown.render([[nil, [result(entry("slow", 1_000), entry("fast", 4_000))]]])
    rows = table_rows(md)
    assert_equal ["Benchmark", "i/s", "±", "vs fastest"], rows[0]
    assert_equal ["`slow`", "1.000k", "0.0%", "**4.00 ± 0.00× slower**"], rows[2]
    assert_equal ["`fast`", "4.000k", "0.0%", "fastest"], rows[3]
  end

  def test_single_benchmark_has_no_comparison_column
    md = IPS::Markdown.render([[nil, [result(entry("only", 1_000))]]])
    assert_equal ["Benchmark", "i/s", "±"], table_rows(md)[0]
  end

  def test_variants_compare_against_first
    md = IPS::Markdown.render([
      ["main", [result(entry("a", 1_000), entry("b", 2_000))]],
      ["abc123", [result(entry("a", 3_000), entry("b", 1_000))]]
    ], variant_header: "Commit")
    rows = table_rows(md)
    assert_equal ["Benchmark", "Commit", "i/s", "±", "vs `main`"], rows[0]
    assert_equal ["`a`", "`main`", "1.000k", "0.0%", "baseline"], rows[2]
    assert_equal 5, rows[1].size
    assert_equal ["", "`abc123`", "3.000k", "0.0%", "**3.00 ± 0.00× faster**"], rows[3]
    assert_equal ["`b`", "`main`", "2.000k", "0.0%", "baseline"], rows[4]
    assert_equal ["", "`abc123`", "1.000k", "0.0%", "**2.00 ± 0.00× slower**"], rows[5]
  end

  def test_sources_are_collapsed_under_the_table
    md = IPS::Markdown.render([[nil, [result(entry("x", 1))]]],
      sources: [["`bench.rb`", "ruby", "x = 1"], [nil, "yaml", "a: ```b```"]])
    assert md.start_with?("| Benchmark"), md
    assert_includes md, "|\n\n<details><summary>Benchmark code</summary>\n\n" \
      "`bench.rb`\n\n```ruby\nx = 1\n```\n\n````yaml\na: ```b```\n````\n\n</details>\n\n" \
      "<details><summary>Environment</summary>"
  end

  def test_no_code_section_without_sources
    md = IPS::Markdown.render([[nil, [result(entry("x", 1))]]])
    refute_includes md, "Benchmark code"
  end

  def test_overlapping_error_is_not_called_faster
    md = IPS::Markdown.render([
      ["a", [result(entry("x", 1_000, jitter: 0.2))]],
      ["b", [result(entry("x", 1_050, jitter: 0.2))]]
    ])
    assert_match(/same within error \(1\.05 ± 0\.\d\d×\)/, md)
    refute_match(/faster|slower/, md)
  end

  def test_runs_are_aggregated
    md = IPS::Markdown.render([[nil, [result(entry("x", 1_000)), result(entry("x", 3_000))]]], runs: 2)
    assert_equal ["`x`", "2.000k", "50.0%"], table_rows(md)[2]
    assert_match(/2 runs/, md)
  end

  def test_multiple_ips_run_calls_per_run
    md = IPS::Markdown.render([[nil, [result(entry("a", 1_000)), result(entry("b", 2_000))]]])
    assert_equal ["`a`", "`b`"], table_rows(md)[2..].map(&:first)
  end

  def test_environment
    md = IPS::Markdown.render([
      ["3.4", [result(entry("x", 1), description: "ruby 3.4.0")]],
      ["4.0", [result(entry("x", 1), description: "ruby 4.0.0")]]
    ], command: "ips --ruby 3.4 --ruby 4.0 -e x")
    assert_includes md, "<details><summary>Environment</summary>"
    assert_includes md, "$ ips --ruby 3.4 --ruby 4.0 -e x\n"
    assert_includes md, "- `3.4`: `ruby 3.4.0`\n"
    assert_includes md, "- `4.0`: `ruby 4.0.0`\n"
    assert_includes md, "- ips #{IPS::VERSION}\n"
  end

  def test_code_escapes_for_table_cells
    assert_equal "`a\\|b`", IPS::Markdown.code("a|b")
    assert_equal "``x`y``", IPS::Markdown.code("x`y")
    assert_equal "`` `x` ``", IPS::Markdown.code("`x`")
    assert_equal "`a b`", IPS::Markdown.code("a\n  b")
  end

  def test_columns_line_up_as_plain_text
    md = IPS::Markdown.render([[nil, [result(entry("short", 1_000), entry("a much longer label", 2_000_000))]]])
    lines = md.lines.grep(/\A\|/).map(&:chomp)
    pipes = lines.map { |l| l.each_char.with_index.select { |c, _| c == "|" }.map(&:last) }
    assert_equal 1, pipes.uniq.size, lines.join("\n")
  end

  def test_result_to_markdown
    md = result(entry("a", 1_000), entry("b", 2_000)).to_markdown
    assert_equal ["`a`", "`b`"], table_rows(md)[2..].map(&:first)
  end
end
