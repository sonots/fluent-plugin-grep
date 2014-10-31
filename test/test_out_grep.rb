require_relative 'helper'
require 'fluent/test'
require 'fluent/plugin/out_grep'

Fluent::Test.setup

class GrepOutputTest < Test::Unit::TestCase
  setup do
    @tag = 'syslog.host1'
    @time = Fluent::Engine.now
  end

  def create_driver(conf)
    Fluent::Test::OutputTestDriver.new(Fluent::GrepOutput, @tag).configure(conf)
  end

  def emit(config, msgs = [''])
    d = create_driver(config)
    msgs.each do |msg|
      d.run { d.emit({'foo' => 'bar', 'message' => msg}, @time) }
    end

    @instance = d.instance
    d.emits
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
      tag, time, record = emits.first
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
      tag, time, record = emits.first
      assert_equal('foo', tag)
    end

    test 'add_tag_prefix' do
      emits = emit('add_tag_prefix foo')
      tag, time, record = emits.first
      assert_equal("foo.#{@tag}", tag)
    end

    test 'remove_tag_prefix' do
      emits = emit('remove_tag_prefix syslog')
      tag, time, record = emits.first
      assert_equal("host1", tag)
    end

    test 'add_tag_suffix' do
      emits = emit('add_tag_suffix foo')
      tag, time, record = emits.first
      assert_equal("#{@tag}.foo", tag)
    end

    test 'remove_tag_suffix' do
      emits = emit('remove_tag_suffix host1')
      tag, time, record = emits.first
      assert_equal("syslog", tag)
    end

    test 'add_tag_prefix.' do
      emits = emit('add_tag_prefix foo.')
      tag, time, record = emits.first
      assert_equal("foo.#{@tag}", tag)
    end

    test 'remove_tag_prefix.' do
      emits = emit('remove_tag_prefix syslog.')
      tag, time, record = emits.first
      assert_equal("host1", tag)
    end

    test '.add_tag_suffix' do
      emits = emit('add_tag_suffix .foo')
      tag, time, record = emits.first
      assert_equal("#{@tag}.foo", tag)
    end

    test '.remove_tag_suffix' do
      emits = emit('remove_tag_suffix .host1')
      tag, time, record = emits.first
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
      tag, time, record = emits.first
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
    def capture_log(log)
      tmp = log.out
      log.out = StringIO.new
      yield log
      return log.out.string
    ensure
      log.out = tmp
    end

    if Fluent::VERSION >= "0.10.43"
      test "log_level info" do
        d = create_driver('log_level info')
        log = d.instance.log
        assert_equal("", capture_log(log) {|log| log.debug "foobar" })
        assert_include(capture_log(log) {|log| log.info "foobar" }, "foobar")
      end
    end

    test "should work" do
      d = create_driver('')
      log = d.instance.log
      assert_include(capture_log(log) {|log| log.info "foobar" }, "foobar")
    end
  end
end
