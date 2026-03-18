# Comparing different ways to check string contents
#
# Usage:
#   ruby -I lib examples/string_matching.rb

require "bundler/setup"
require "ips"

string = "the quick brown fox jumps over the lazy dog"

IPS.run do |x|
  x.report("include?")  { string.include?("fox") }
  x.report("match?")    { string.match?(/fox/) }
  x.report("index")     { string.index("fox") }
  x.report("=~")        { string =~ /fox/ }
end
