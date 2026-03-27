# frozen_string_literal: true

require "ips/version"
require "ips/timing"
require "ips/display"
require "ips/job"

module IPS
  @results = []

  def self.run(time: 5, warmup: time * 0.2, summary: true, debug: false, frozen_string_literal: true, out: $stdout)
    job = Job.new(time: time, warmup: warmup, summary: summary, debug: debug, frozen_string_literal: frozen_string_literal, out: out)
    yield job
    result = job.run
    @results << result
    result
  end

  def self.report(label = nil, action = nil, &block)
    action ||= block || label || raise(ArgumentError, "no action or block given")
    label ||= action.is_a?(String) ? action : "block"
    run do |x|
      x.report(label, action)
    end
  end

  class << self
    attr_reader :results
    alias_method :ips, :run
  end
end

Ips = IPS
