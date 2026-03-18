# Basic usage example
#
# Usage:
#   ruby -I lib examples/basic.rb

require "bundler/setup"
require "ips"

IPS.run do |x|
  x.report("addition")       { 1 + 1 }
  x.report("multiplication") { 2 * 3 }
end
