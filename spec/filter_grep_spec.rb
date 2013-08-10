# encoding: UTF-8
require_relative 'spec_helper'
include Fluentd::PluginSpecHelper

module Fluentd::PluginSpecHelper::GrepFilter
  # Create the GrepFilter Plugin TestDriver
  # let(:config)
  def create_driver
    generate_driver(Fluentd::Plugin::GrepFilter, config)
  end

  # Emit messages and receive events (outputs)
  # @param driver [PluginDriver] TestDriver
  # @return output events
  # let(:tag)
  # let(:time)
  # let(:messages)
  def emit(driver = create_driver)
    driver.run do |d|
      d.with(tag, time) do |d|
        messages.each {|message| d.pitch({'foo'=>'bar', 'message' => message}) }
      end
    end
    driver.events
  end
end

describe Fluentd::Plugin::GrepFilter do
  include Fluentd::PluginSpecHelper::GrepFilter

  CONFIG = %[
    input_key message
  ]
  let(:tag) { 'syslog.host1' }

  describe 'test configure' do
    describe 'bad configuration' do
      context "lack of requirements" do
        let(:config) { '' }
        it { expect { create_driver }.to raise_error(Fluentd::ConfigError) }
      end
    end

    describe 'good configuration' do
      subject { create_driver.instance }

      context "check default" do
        let(:config) { CONFIG }
        its(:input_key) { should == "message" }
        its(:regexp) { should be_nil }
        its(:exclude) { should be_nil }
        its(:tag) { should be_nil }
        its(:add_tag_prefix) { should == 'greped' }
      end
    end
  end

  describe 'test emit' do
    let(:time) { Time.now.to_i }
    let(:messages) do
      [
        "2013/01/13T07:02:11.124202 INFO GET /ping",
        "2013/01/13T07:02:13.232645 WARN POST /auth",
        "2013/01/13T07:02:21.542145 WARN GET /favicon.ico",
        "2013/01/13T07:02:43.632145 WARN POST /login",
      ]
    end

    context 'no grep' do
      let(:config) { CONFIG }
      it 'should pass all messages' do
        expect(emit["greped.#{tag}"].size).to eql(messages.size)
      end
    end

    context 'regexp' do
      let(:config) do
        CONFIG + %[
          regexp WARN
        ]
      end
      it 'should grep WARN' do
        emit["greped.#{tag}"].each { |event| expect(event.record['message']).to include('WARN') }
      end
    end

    context 'exclude' do
      let(:config) do
        CONFIG + %[
          exclude favicon
        ]
      end
      it 'should exclude favicon' do
        emit["greped.#{tag}"].each { |event| expect(event.record['message']).not_to include('favicon') }
      end
    end

    context 'tag' do
      let(:config) do
        CONFIG + %[
          regexp ping
          tag foo
        ]
      end
      it 'should set tag' do
        expect(emit).to have_key('foo')
      end
    end

    context 'add_tag_prefix' do
      let(:config) do
        CONFIG + %[
          regexp ping
          add_tag_prefix foo
        ]
      end
      it 'should add tag prefix' do
        expect(emit).to have_key("foo.#{tag}")
      end
    end

    context 'replace_invalid_sequence' do
      let(:config) do
        CONFIG + %[
          regexp WARN
          replace_invalid_sequence true
        ]
      end
      let(:messages) do
        [
          "\xff".force_encoding('UTF-8'),
        ]
      end
      it 'should replace invalid sequence' do
        expect { emit }.not_to raise_error
      end
    end
  end

  describe 'grep non-string jsonable values' do
    let(:time) { Time.now.to_i }
    let(:config) { CONFIG + %[regexp 0] }
    let(:messages) { [0] }

    context "array" do
      let(:messages) { [["0"]] }
      it { expect { emit }.not_to raise_error }
    end

    context "hash" do
      let(:messages) { [{"0"=>"0"}] }
      it { expect { emit }.not_to raise_error }
    end

    context "integer" do
      let(:messages) { [0] }
      it { expect { emit }.not_to raise_error }
    end

    context "float" do
      let(:messages) { [0.1] }
      it { expect { emit }.not_to raise_error }
    end

    context "boolean" do
      let(:config) { CONFIG + %[regexp true] }
      let(:messages) { [true] }
      it { expect { emit }.not_to raise_error }
    end
  end

end
