# frozen_string_literal: true

module IPS
  class Display
    BAR_WIDTH = 30

    def initialize(labels, out: $stdout)
      @out = out
      @max_label = labels.map(&:size).max
      @max_label = 20 if @max_label < 20
      @tty = @out.tty?
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
      @out.printf "%#{@max_label}s: %10s i/s (±%4.1f%%)\n",
        result.label, format_ips(result.ips), result.error_pct
    end

    def summary(results)
      return if results.size < 2

      sorted = results.sort_by { |r| -r.ips }
      best = sorted.first

      @out.puts "\nSummary"
      @out.puts "  #{best.label} ran"

      sorted[1..].each do |r|
        ratio = best.ips / r.ips
        ratio_error = ratio * Math.sqrt((best.stddev / best.ips)**2 + (r.stddev / r.ips)**2)
        @out.printf "    %.2f ± %.2f times faster than %s\n",
          ratio, ratio_error, r.label
      end
    end

    def format_ips(ips)
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
