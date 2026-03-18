# Demonstrates how benchmark-ips hides rare stalls.
#
# Every 100th iteration sleeps for 1 second.
# Real throughput: ~100 i/s
# benchmark-ips reports: ~5.9M i/s (!!!)
#
# Usage:
#   ruby -I lib examples/outlier.rb

require "benchmark/ips"
require "bundler/setup"
require "ips"

i = 0
j = 0

if false
puts "=== benchmark-ips ==="
Benchmark.ips do |x|
  x.report("periodic stall") do
    sleep 1 if i % 100 == 0
    i += 1
  end
  x.compare!
end
end

puts
puts "=== IPS ==="
IPS.run do |x|
  x.report("periodic stall") do
    sleep 1 if j % 100 == 0
    j += 1
  end
end
