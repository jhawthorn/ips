# frozen_string_literal: true

begin
  require "io/console"
rescue LoadError
end

module IPS
  class Display
    BAR_WIDTH = 30

    def initialize(labels, out: $stdout, debug: false)
      @out = out
      @max_label = labels.map(&:size).max
      @max_label = 20 if @max_label < 20
      @tty = @out.tty? && !debug && terminal_wide_enough?
    end

    def start_item(label, total_ns)
      @item_label = label
      @item_start = Timing.now
      @item_total_ns = total_ns
      progress
    end

    def progress(estimate: nil)
      return unless @tty
      elapsed_ns = Timing.now - @item_start
      fraction = (elapsed_ns.to_f / @item_total_ns).clamp(0.0, 1.0)
      filled = (fraction * BAR_WIDTH).to_i
      empty = BAR_WIDTH - filled
      remaining_ns = @item_total_ns - elapsed_ns
      remaining_s = remaining_ns > 0 ? (remaining_ns.to_f / Timing::NANOSECONDS_PER_SECOND).ceil : 0
      bar = "█" * filled + "░" * empty
      est = estimate ? "%10s i/s" % format_ips(estimate) : "              "
      @out.print "\r%#{@max_label}s: %s %s ETA %ds " % [@item_label, est, bar, remaining_s]
      @out.flush
    end

    def finish_item(result)
      @out.print "\r\e[2K" if @tty
      gc = result.gc_pct >= 1.0 ? ", GC %4.1f%%" % result.gc_pct : ""
      error = result.error_pct > 100 ? ">100" : "%4.1f" % result.error_pct
      @out.printf "%#{@max_label}s: %10s i/s (±%s%%%s)\n",
        result.label, format_ips(result.ips), error, gc
    end

    def summary(results)
      return if results.size < 2
      pairs = results.map { |r| [r.label, r] }
      Display.compare(pairs, out: @out)
    end

    def self.compare(pairs, out: $stdout)
      return if pairs.size < 2

      sorted = pairs.sort_by { |_, e| -e.ips }
      best_label, best = sorted.first

      out.puts "\nSummary"
      out.puts "  #{best_label} ran"

      sorted[1..].each do |label, entry|
        ratio = best.ips / entry.ips
        ratio_error = ratio * Math.sqrt((best.stddev / best.ips)**2 + (entry.stddev / entry.ips)**2)
        out.printf "    %.2f ± %.2f times faster than %s\n",
          ratio, ratio_error, label
      end
    end

    def terminal_wide_enough?
      return true unless @out.respond_to?(:winsize)
      # label + ": " + estimate + " " + bar + " ETA Ns "
      min_width = @max_label + 2 + 14 + 1 + BAR_WIDTH + 8
      _, cols = @out.winsize
      cols >= min_width
    end

    def format_ips(ips)
      Display.format_ips(ips)
    end

    def self.format_ips(ips)
      if ips >= 1_000_000_000
        "%.3fB" % (ips / 1_000_000_000.0)
      elsif ips >= 1_000_000
        "%.3fM" % (ips / 1_000_000.0)
      elsif ips >= 1_000
        "%.3fk" % (ips / 1_000.0)
      else
        "%.3f" % ips
      end
    end
  end
end
