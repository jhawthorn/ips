# frozen_string_literal: true

# A shim that lets scripts written for the benchmark-ips gem
# (`require "benchmark/ips"` and `Benchmark.ips`) run under ips. The ips CLI
# puts this directory on the load path; it is not otherwise visible.
require "stringio"
require "ips"

module Benchmark
  # The subset of Benchmark::IPS::Job that maps onto IPS::Job. The comparison
  # is always printed, so compare! does nothing.
  class IPSJob
    def initialize(job)
      @job = job
    end

    # Like the real one, ignores options ips has no equivalent for.
    def config(opts)
      @job.time = opts[:time] if opts[:time]
      @job.warmup = opts[:warmup] if opts[:warmup]
    end

    def time=(seconds)
      @job.time = seconds
    end

    def warmup=(seconds)
      @job.warmup = seconds
    end

    def report(label = "", action = nil, &block)
      @job.report(label.to_s, action, &block)
    end
    alias_method :item, :report

    def compare!(*) = nil

    # Accepted so scripts run, but not supported; say so rather than silently
    # doing nothing.
    %i[hold! save! json!].each do |name|
      define_method(name) do |*|
        warn "ips: #{name} is not supported by the benchmark/ips shim and is ignored"
      end
    end
  end

  def self.ips(*args)
    if args[0].is_a?(Hash)
      time, warmup, quiet = args[0].values_at(:time, :warmup, :quiet)
    else
      time, warmup, quiet = args
    end

    opts = {}
    opts[:time] = time if time
    opts[:warmup] = warmup if warmup
    opts[:out] = StringIO.new if quiet

    IPS.run(**opts) { |job| yield IPSJob.new(job) }
  end
end
