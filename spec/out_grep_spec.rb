# encoding: UTF-8
require_relative 'spec_helper'

describe Fluent::GrepOutput do
  before { Fluent::Test.setup }
  CONFIG = %[
    input_key message
  ]
  let(:tag) { 'syslog.host1' }
  let(:driver) { Fluent::Test::OutputTestDriver.new(Fluent::GrepOutput, tag).configure(config) }

  describe 'test configure' do
    describe 'bad configuration' do
      context "lack of requirements" do
        let(:config) { '' }
        it { expect { driver }.to raise_error(Fluent::ConfigError) }
      end
    end

    describe 'good configuration' do
      subject { driver.instance }

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
    let(:emit) do
      driver.run { messages.each {|message| driver.emit({'foo'=>'bar', 'message' => message}, time) } }
    end

    context 'default' do
      let(:config) { CONFIG }
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:11.124202 INFO GET /ping"})
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:13.232645 WARN POST /auth"})
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:21.542145 WARN GET /favicon.ico"})
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:43.632145 WARN POST /login"})
      end
      it { emit }
    end

    context 'regexp' do
      let(:config) do
        CONFIG + %[
          regexp WARN
        ]
      end
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:13.232645 WARN POST /auth"})
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:21.542145 WARN GET /favicon.ico"})
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:43.632145 WARN POST /login"})
      end
      it { emit }
    end

    context 'exclude' do
      let(:config) do
        CONFIG + %[
          exclude favicon
        ]
      end
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:11.124202 INFO GET /ping"})
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:13.232645 WARN POST /auth"})
        Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:43.632145 WARN POST /login"})
      end
      it { emit }
    end

    context 'tag' do
      let(:config) do
        CONFIG + %[
          regexp ping
          tag foo
        ]
      end
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("foo", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:11.124202 INFO GET /ping"})
      end
      it { emit }
    end

    context 'add_tag_prefix' do
      let(:config) do
        CONFIG + %[
          regexp ping
          add_tag_prefix foo
        ]
      end
      before do
        Fluent::Engine.stub(:now).and_return(time)
        Fluent::Engine.should_receive(:emit).with("foo.#{tag}", time, {'foo'=>'bar', 'message'=>"2013/01/13T07:02:11.124202 INFO GET /ping"})
      end
      it { emit }
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
      before do
        Fluent::Engine.stub(:now).and_return(time)
      end
      it { expect { emit }.not_to raise_error }
    end
  end

  describe 'grep non-string jsonable values' do
    let(:config) { CONFIG + %[regexp 0] }
    let(:message) { 0 }
    let(:time) { Time.now.to_i }
    let(:emit) { driver.run { driver.emit({'foo'=>'bar', 'message' => message}, time) } }
    before do
      Fluent::Engine.stub(:now).and_return(time)
      Fluent::Engine.should_receive(:emit).with("greped.#{tag}", time, {'foo'=>'bar', 'message'=>message})
    end

    context "array" do
      let(:message) { ["0"] }
      it { emit }
    end

    context "hash" do
      let(:message) { ["0"=>"0"] }
      it { emit }
    end

    context "integer" do
      let(:message) { 0 }
      it { emit }
    end

    context "float" do
      let(:message) { 0.1 }
      it { emit }
    end

    context "boolean" do
      let(:config) { CONFIG + %[regexp true] }
      let(:message) { true }
      it { emit }
    end
  end
end
