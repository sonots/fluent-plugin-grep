# encoding: UTF-8
require_relative 'spec_helper'

# setup
Fluent::Test.setup
config = %[
  input_key message
  grep INFO
  exlude something
  remove_tag_prefix foo
  add_tag_prefix bar
]
time = Time.now.to_i
tag = 'foo.bar'
driver = Fluent::Test::OutputTestDriver.new(Fluent::GrepOutput, tag).configure(config)

# bench
require 'benchmark'
message = "2013/01/13T07:02:11.124202 INFO GET /ping"
n = 100000
Benchmark.bm(7) do |x|
  x.report { driver.run { n.times { driver.emit({'message' => message}, time) } } }
end

# BEFORE TAG_PROC
#              user     system      total        real
#          2.560000   0.030000   2.590000 (  3.169847)
# AFTER  TAG_PROC (0.2.1)
#              user     system      total        real
#          2.480000   0.040000   2.520000 (  3.085798)
# AFTER  regexps, exludes (0.3.0) 
#              user     system      total        real
#          2.700000   0.050000   2.750000 (  3.340524)
# AFTER  add_tag_suffix, remove_tag_suffix (0.3.3)
#              user     system      total        real
#          2.470000   0.020000   2.490000 (  3.012241)
