# frozen_string_literal: true

require "ips/display"
require "ips/version"

module IPS
  # Renders results as GitHub-flavoured markdown, ready to paste into a pull
  # request or issue.
  module Markdown
    module_function

    # variants: [[label, [Result, ...]], ...] where each variant's results are
    # every run of it, in order. A script that calls IPS.run more than once
    # produces several results per run; their entries are concatenated.
    #
    # sources: [[title, lang, source], ...] shown as code blocks in a
    # collapsed section under the table, so readers can see what was
    # measured. title is markdown, or nil.
    def render(variants, runs: 1, command: nil, variant_header: "Variant", sources: [])
      variants = variants.reject { |_, results| results.empty? }
      return "" if variants.empty?

      rows = variants.map { |label, results| [label, results, stats(results, runs)] }
      benchmarks = rows.first[2].map(&:first)

      out = +""
      if rows.size == 1
        out << single_table(rows.first[2])
      else
        out << matrix_table(rows, benchmarks, variant_header)
      end
      out << "\n" << code_section(sources) if sources.any?
      out << "\n" << environment(rows, runs: runs, command: command)
      out
    end

    # One variant: list every benchmark, compared against the fastest, the same
    # way the plain text Summary does.
    def single_table(pairs)
      fastest = pairs.max_by { |_, s| s.ips }[1]
      compare = pairs.size > 1
      header = ["Benchmark", "i/s", "±"]
      align = [:left, :right, :right]
      if compare
        header << "vs fastest"
        align << :left
      end
      rows = pairs.map do |label, stat|
        row = [code(label), Display.format_ips(stat.ips), error(stat)]
        row << (stat.equal?(fastest) ? "fastest" : ratio(stat, fastest)) if compare
        row
      end
      table(header, align, rows)
    end

    # Several variants (rubies, commits, or both): one row per benchmark and
    # variant, each compared against the first variant, which is the baseline.
    # The CLI puts the --sha commits first, so that's the first of those, or
    # the first --ruby when there are no commits.
    def matrix_table(variants, benchmarks, variant_header)
      header = ["Benchmark", variant_header, "i/s", "±", "vs #{text(variants.first[0])}"]
      align = [:left, :left, :right, :right, :left]

      rows = []
      benchmarks.each_with_index do |bench, i|
        base = variants.first[2][i]&.last
        variants.each_with_index do |(label, _, pairs), j|
          stat = pairs[i]&.last
          next unless stat
          rows << [j == 0 ? code(bench) : "", text(label), Display.format_ips(stat.ips), error(stat),
            j == 0 || base.nil? ? "baseline" : ratio(stat, base)]
        end
      end
      table(header, align, rows)
    end

    # A table padded so its columns also line up when read as plain text.
    def table(header, align, rows)
      widths = header.each_index.map do |i|
        [3, *([header] + rows).map { |r| r[i].size }].max
      end
      line = ->(cells) {
        padded = cells.each_with_index.map { |c, i|
          align[i] == :right ? c.rjust(widths[i]) : c.ljust(widths[i])
        }
        "| #{padded.join(" | ")} |"
      }
      rule = widths.each_with_index.map { |w, i|
        align[i] == :right ? "-" * (w - 1) + ":" : ":" + "-" * (w - 1)
      }
      lines = [line.(header), "| #{rule.join(" | ")} |"]
      rows.each { |r| lines << line.(r) }
      lines.join("\n") << "\n"
    end

    def code_section(sources)
      out = +"<details><summary>Benchmark code</summary>\n\n"
      sources.each do |title, lang, source|
        out << "#{title}\n\n" if title
        out << fenced(lang, source) << "\n"
      end
      out << "</details>\n"
    end

    def environment(rows, runs:, command:)
      descriptions = rows.map { |label, results, _| [label, results.first.ruby_description] }
      lines = []
      lines << "<details><summary>Environment</summary>"
      lines << ""
      if command
        lines << "```console"
        lines << "$ #{command}"
        lines << "```"
        lines << ""
      end
      if descriptions.map(&:last).uniq.size == 1
        lines << "- #{code(descriptions.first[1])}"
      else
        descriptions.each do |label, desc|
          lines << "- #{text(label)}: #{code(desc)}"
        end
      end
      lines << "- #{runs} runs, each reported value is the mean across runs" if runs > 1
      lines << "- ips #{IPS::VERSION}"
      lines << ""
      lines << "</details>"
      lines.join("\n") << "\n"
    end

    # [[benchmark_label, stat], ...] for one variant. With several runs the
    # stat is an aggregate over runs, matching Result.compare_aggregate.
    def stats(results, runs)
      runs = 1 if runs < 1 || results.size % runs != 0
      per_run = results.each_slice(results.size / runs).map { |rs| rs.flat_map(&:entries) }
      per_run.first.each_index.map do |i|
        entries = per_run.map { |es| es[i] }.compact
        stat = entries.size == 1 ? entries.first : Result::Entry::Aggregate.new(entries)
        [entries.first.label, stat]
      end
    end

    def error(stat)
      pct = stat.error_pct
      pct > 100 ? ">100%" : "%.1f%%" % pct
    end

    # How +stat+ compares to +base+, with the propagated error. When the error
    # range includes 1× we don't claim either direction.
    def ratio(stat, base)
      r = stat.ips / base.ips
      rel = Math.sqrt((stat.stddev / stat.ips)**2 + (base.stddev / base.ips)**2)
      err = r * rel
      if (r - 1).abs <= err
        "same within error (%.2f ± %.2f×)" % [r, err]
      elsif r > 1
        "**%.2f ± %.2f× faster**" % [r, err]
      else
        inv = 1 / r
        "**%.2f ± %.2f× slower**" % [inv, inv * rel]
      end
    end

    # A fenced code block, with a fence longer than any backtick run inside.
    def fenced(lang, source)
      longest = source.scan(/`{3,}/).map(&:size).max || 2
      fence = "`" * (longest + 1)
      source = source.end_with?("\n") ? source : "#{source}\n"
      "#{fence}#{lang}\n#{source}#{fence}\n"
    end

    # Plain text that is safe inside a table cell. Used for variant labels
    # rather than a code span, because a label like `main (abc1234)` holds a
    # commit SHA, and GitHub links those; a link inside a code span renders
    # as a mess.
    def text(text)
      text.to_s.gsub(/\s*\n\s*/, " ").strip.gsub(/[\\`*_\[\]<>|~]/) { "\\#{$&}" }
    end

    # An inline code span that is safe inside a table cell.
    def code(text)
      text = text.to_s.gsub(/\s*\n\s*/, " ").strip
      longest = text.scan(/`+/).map(&:size).max || 0
      fence = "`" * (longest + 1)
      pad = text.start_with?("`") || text.end_with?("`") ? " " : ""
      "#{fence}#{pad}#{text.gsub("|", "\\|")}#{pad}#{fence}"
    end
  end
end
