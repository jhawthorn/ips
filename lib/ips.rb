# frozen_string_literal: true

require "ips/version"
require "ips/timing"
require "ips/display"
require "ips/job"

module IPS
  def self.run(time: 5, warmup: 2)
    job = Job.new(time: time, warmup: warmup)
    yield job
    job.run
  end
end

Ips = IPS
