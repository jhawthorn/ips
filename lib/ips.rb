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

  class << self
    alias_method :ips, :run
  end
end

Ips = IPS
