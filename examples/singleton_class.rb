# Singleton class creation benchmark
# From https://bugs.ruby-lang.org/issues/21856
#
# Usage:
#   ruby -I lib examples/singleton_class.rb

require "bundler/setup"
require "ips"

IPS.run do |x|
  x.report("singleton_class") do
    Object.new.singleton_class
  end
end
