# Hash vs Struct vs Data for simple records
#
# Usage:
#   ruby -I lib examples/hash_vs_struct.rb

require "bundler/setup"
require "ips"

MyStruct = Struct.new(:name, :age)
MyData = Data.define(:name, :age)

IPS.run do |x|
  x.report("Hash.new")   { { name: "Alice", age: 30 } }
  x.report("Struct.new") { MyStruct.new("Alice", 30) }
  x.report("Data.new")   { MyData.new(name: "Alice", age: 30) }
end
