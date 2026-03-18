# frozen_string_literal: true

require_relative "ips/version"
require_relative "ips/timing"
require_relative "ips/job"

module IPS
  def self.run(time: 5, warmup: 2)
    job = Job.new(time: time, warmup: warmup)
    yield job
    job.run
  end
end

Ips = IPS
