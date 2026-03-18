# Using the manual loop style for ultra-fast operations
# where per-call overhead matters
#
# Usage:
#   ruby -I lib examples/manual_loop.rb

require "bundler/setup"
require "ips"

IPS.run do |x|
  x.report("block style") { 1 + 1 }

  x.report("manual loop") { |n|
    i = 0
    while i < n
      1 + 1
      i += 1
    end
  }
end
