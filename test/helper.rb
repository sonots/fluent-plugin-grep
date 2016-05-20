require 'test/unit'
require 'fluent/log'
require 'fluent/test'
require 'fluent/version'

unless defined?(Test::Unit::AssertionFailedError)
  class Test::Unit::AssertionFailedError < StandardError
  end
end
