# Comparing allocation-heavy vs allocation-free approaches
#
# Usage:
#   ruby -I lib examples/gc_pressure.rb

require "bundler/setup"
require "ips"

array = (1..1000).to_a

IPS.run do |x|
  x.report("map + sum")  { array.map { |i| i * 2 }.sum }
  x.report("sum block")  { array.sum { |i| i * 2 } }
  x.report("inject")     { array.inject(0) { |acc, i| acc + i * 2 } }
end
