# frozen_string_literal: true

require "ips/version"
require "ips/timing"
require "ips/display"
require "ips/job"

module IPS
  def self.run(time: 5, warmup: 2, out: $stdout)
    job = Job.new(time: time, warmup: warmup, out: out)
    yield job
    job.run
  end

  def self.report(label = nil, action = nil, &block)
    action ||= block || label || raise(ArgumentError, "no action or block given")
    label ||= action.is_a?(String) ? action : "block"
    run do |x|
      x.report(label, action)
    end
  end

  class << self
    alias_method :ips, :run
  end
end

Ips = IPS
