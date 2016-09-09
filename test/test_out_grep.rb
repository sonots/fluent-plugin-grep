require_relative 'helper'
require 'fluent/test'
require 'fluent/test/driver/output'
require 'fluent/plugin/out_grep'

Fluent::Test.setup

class GrepOutputTest < Test::Unit::TestCase
  setup do
    @tag = 'syslog.host1'
    @time = Fluent::Engine.now
  end

  def create_driver(conf, syntax = :v1)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::GrepOutput).configure(conf, syntax: syntax)
  end

  def emit(config, msgs = [''])
    d = create_driver(config)
    d.run(default_tag: @tag) do
      msgs.each do |msg|
        d.feed(@time, {'foo' => 'bar', 'message' => msg})
      end
    end

    @instance = d.instance
    d.events
  end

  sub_test_case 'configure' do
    test 'check default' do
      d = nil
      assert_nothing_raised do
        d = create_driver('')
      end
      assert_empty(d.instance.regexps)
      assert_empty(d.instance.excludes)
    end

    test "regexpN can contain a space" do
      d = create_driver(%[regexp1 message  foo])
      assert_equal(Regexp.compile(/ foo/), d.instance.regexps['message'])
    end

    test "excludeN can contain a space" do
      d = create_driver(%[exclude1 message  foo])
      assert_equal(Regexp.compile(/ foo/), d.instance.excludes['message'])
    end

    test "regexp contains a duplicated key" do
      config = %[
        input_key message
        regexp foo
        regexp1 message foo
      ]
      assert_raise(Fluent::ConfigError) do
        create_driver(config)
      end
    end

    test "exclude contains a duplicated key" do
      config = %[
        input_key message
        exclude foo
        exclude1 message foo
      ]
      assert_raise(Fluent::ConfigError) do
        create_driver(config)
      end
    end

    if Fluent::VERSION >= "0.12"
      test "@label" do
        Fluent::Engine.root_agent.add_label('@foo')
        create_driver(%[@label @foo])
        # In v0.14, router is overridden with TestEventRouter in test.
        assert(Fluent::Engine.root_agent.find_label('@foo'))

        emits = emit(%[@label @foo], ['foo'])
        tag, = emits.first
        assert_equal(@tag, tag) # tag is not modified
      end
    end
  end

  sub_test_case 'emit' do
    def messages
      [
        "2013/01/13T07:02:11.124202 INFO GET /ping",
        "2013/01/13T07:02:13.232645 WARN POST /auth",
        "2013/01/13T07:02:21.542145 WARN GET /favicon.ico",
        "2013/01/13T07:02:43.632145 WARN POST /login",
      ]
    end

    test 'empty config' do
      emits = emit('', messages)
      assert_equal(4, emits.size)
      tag, _time, record = emits.first
      assert_equal("greped.#{@tag}", tag)
      assert_not_nil(record, 'foo')
      assert_not_nil(record, 'message')
    end

    test 'regexp' do
      emits = emit("input_key message\nregexp WARN", messages)
      assert_equal(3, emits.size)
      assert_block('only WARN logs') do
        emits.all? { |tag, time, record|
          !record['message'].include?('INFO')
        }
      end
    end

    test 'regexpN' do
      emits = emit('regexp1 message WARN', messages)
      assert_equal(3, emits.size)
      assert_block('only WARN logs') do
        emits.all? { |tag, time, record|
          !record['message'].include?('INFO')
        }
      end
    end

    test 'exclude' do
      emits = emit("input_key message\nexclude favicon", messages)
      assert_equal(3, emits.size)
      assert_block('remove favicon logs') do
        emits.all? { |tag, time, record|
          !record['message'].include?('favicon')
        }
      end
    end

    test 'excludeN' do
      emits = emit('exclude1 message favicon', messages)
      assert_equal(3, emits.size)
      assert_block('remove favicon logs') do
        emits.all? { |tag, time, record|
          !record['message'].include?('favicon')
        }
      end
    end

    test 'tag' do
      emits = emit('tag foo')
      tag, = emits.first
      assert_equal('foo', tag)
    end

    test 'add_tag_prefix' do
      emits = emit('add_tag_prefix foo')
      tag, = emits.first
      assert_equal("foo.#{@tag}", tag)
    end

    test 'remove_tag_prefix' do
      emits = emit('remove_tag_prefix syslog')
      tag, = emits.first
      assert_equal("host1", tag)
    end

    test 'add_tag_suffix' do
      emits = emit('add_tag_suffix foo')
      tag, = emits.first
      assert_equal("#{@tag}.foo", tag)
    end

    test 'remove_tag_suffix' do
      emits = emit('remove_tag_suffix host1')
      tag, = emits.first
      assert_equal("syslog", tag)
    end

    test 'add_tag_prefix.' do
      emits = emit('add_tag_prefix foo.')
      tag, = emits.first
      assert_equal("foo.#{@tag}", tag)
    end

    test 'remove_tag_prefix.' do
      emits = emit('remove_tag_prefix syslog.')
      tag, = emits.first
      assert_equal("host1", tag)
    end

    test '.add_tag_suffix' do
      emits = emit('add_tag_suffix .foo')
      tag, = emits.first
      assert_equal("#{@tag}.foo", tag)
    end

    test '.remove_tag_suffix' do
      emits = emit('remove_tag_suffix .host1')
      tag, = emits.first
      assert_equal("syslog", tag)
    end

    test 'all tag options' do
      @tag = 'syslog.foo.host1'
      config = %[
        add_tag_prefix foo
        remove_tag_prefix syslog
        add_tag_suffix foo
        remove_tag_suffix host1
      ]
      emits = emit(config)
      tag, = emits.first
      assert_equal("foo.foo.foo", tag)
    end

    test 'with invalid sequence' do
      assert_nothing_raised {
        emit(%[regexp1 message WARN], ["\xff".force_encoding('UTF-8')])
      }
    end
  end

  sub_test_case 'grep non-string jsonable values' do
    data(
      'array' => ["0"],
      'hash' => ["0" => "0"],
      'integer' => 0,
      'float' => 0.1)
    test "value" do |data|
      emits = emit('regexp1 message 0', [data])
      assert_equal(1, emits.size)
    end

    test "value boolean" do
      emits = emit('regexp1 message true', [true])
      assert_equal(1, emits.size)
    end
  end

  sub_test_case 'test log' do
    def mock_logdev(log)
      tmp = log.out
      log.out = StringIO.new
      log.logdev = Fluent::Test::DummyLogDevice.new
      yield log
    ensure
      log.out = tmp
    end

    test "log_level info" do
      d = create_driver('log_level info')
      logger = d.instance.log
      assert_equal(nil, mock_logdev(logger) {|log| log.debug "foobar" })
      assert_include(mock_logdev(logger) {|log| log.warn "foobar" }, "foobar")
    end

    test "should work" do
      d = create_driver('')
      logger = d.instance.log
      assert_include(mock_logdev(logger){|log| log.info "foobar"}, "foobar")
    end
  end
end
