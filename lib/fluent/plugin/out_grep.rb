class Fluent::GrepOutput < Fluent::Output
  Fluent::Plugin.register_output('grep', self)

  REGEXP_MAX_NUM = 20

  config_param :input_key, :string, :default => nil, # obsolete
               :desc => 'The target field key to grep out. Use with regexp or exclude. (obsolete)'
  config_param :regexp, :string, :default => nil, # obsolete
               :desc => 'The filtering regular expression. (obsolete)'
  config_param :exclude, :string, :default => nil, # obsolete
               :desc => 'The excluding regular expression like grep -v. (obsolete)'
  config_param :tag, :string, :default => nil,
               :desc => 'The output tag name.'
  config_param :add_tag_prefix, :string, :default => nil,
               :desc => 'Add tag prefix for output message.'
  config_param :remove_tag_prefix, :string, :default => nil,
               :desc => 'Remove tag prefix for output message.'
  config_param :add_tag_suffix, :string, :default => nil,
               :desc => 'Add tag suffix for output message.'
  config_param :remove_tag_suffix, :string, :default => nil,
               :desc => 'Remove tag suffix for output message.'
  config_param :replace_invalid_sequence, :bool, :default => true,
               :desc => "Replace invalid byte sequence in UTF-8 with '?' character if true."
  (1..REGEXP_MAX_NUM).each {|i| config_param :"regexp#{i}",  :string, :default => nil,
                            :desc => 'The target field key and the filtering regular expression to grep out.' }
  (1..REGEXP_MAX_NUM).each {|i| config_param :"exclude#{i}", :string, :default => nil,
                            :desc => 'The target field key and the excluding regular expression like grep -v.' }

  # for test
  attr_reader :regexps
  attr_reader :excludes

  # To support log_level option implemented by Fluentd v0.10.43
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  # Define `router` method of v0.12 to support v0.10 or earlier
  unless method_defined?(:router)
    define_method("router") { Fluent::Engine }
  end

  def initialize
    require 'string/scrub' if RUBY_VERSION.to_f < 2.1
    super
  end

  def configure(conf)
    super

    @regexps = {}
    @regexps[@input_key] = Regexp.compile(@regexp) if @input_key and @regexp
    (1..REGEXP_MAX_NUM).each do |i|
      next unless conf["regexp#{i}"]
      key, regexp = conf["regexp#{i}"].split(/ /, 2)
      raise Fluent::ConfigError, "regexp#{i} does not contain 2 parameters" unless regexp
      raise Fluent::ConfigError, "regexp#{i} contains a duplicated key, #{key}" if @regexps[key]
      @regexps[key] = Regexp.compile(regexp)
    end

    @excludes = {}
    @excludes[@input_key] = Regexp.compile(@exclude) if @input_key and @exclude
    (1..REGEXP_MAX_NUM).each do |i|
      next unless conf["exclude#{i}"]
      key, exclude = conf["exclude#{i}"].split(/ /, 2)
      raise Fluent::ConfigError, "exclude#{i} does not contain 2 parameters" unless exclude
      raise Fluent::ConfigError, "exclude#{i} contains a duplicated key, #{key}" if @excludes[key]
      @excludes[key] = Regexp.compile(exclude)
    end

    if conf['@label'].nil? and @tag.nil? and @add_tag_prefix.nil? and @remove_tag_prefix.nil? and @add_tag_suffix.nil? and @remove_tag_suffix.nil?
      @add_tag_prefix = 'greped' # not ConfigError to support lower version compatibility
    end
    @tag_proc = tag_proc
  end

  def emit(tag, es, chain)
    emit_tag = @tag_proc.call(tag)

    es.each do |time,record|
      catch(:break_loop) do
        @regexps.each do |key, regexp|
          throw :break_loop unless match(regexp, record[key].to_s)
        end
        @excludes.each do |key, exclude|
          throw :break_loop if match(exclude, record[key].to_s)
        end
        router.emit(emit_tag, time, record)
      end
    end

    chain.next
  rescue => e
    log.warn "out_grep: #{e.class} #{e.message} #{e.backtrace.first}"
  end

  private

  def tag_proc
    rstrip = Proc.new {|str, substr| str.chomp(substr) }
    lstrip = Proc.new {|str, substr| str.start_with?(substr) ? str[substr.size..-1] : str }
    tag_prefix = "#{rstrip.call(@add_tag_prefix, '.')}." if @add_tag_prefix
    tag_suffix = ".#{lstrip.call(@add_tag_suffix, '.')}" if @add_tag_suffix
    tag_prefix_match = "#{rstrip.call(@remove_tag_prefix, '.')}." if @remove_tag_prefix
    tag_suffix_match = ".#{lstrip.call(@remove_tag_suffix, '.')}" if @remove_tag_suffix
    tag_fixed = @tag if @tag
    if tag_fixed
      Proc.new {|tag| tag_fixed }
    elsif tag_prefix_match and tag_suffix_match
      Proc.new {|tag| "#{tag_prefix}#{rstrip.call(lstrip.call(tag, tag_prefix_match), tag_suffix_match)}#{tag_suffix}" }
    elsif tag_prefix_match
      Proc.new {|tag| "#{tag_prefix}#{lstrip.call(tag, tag_prefix_match)}#{tag_suffix}" }
    elsif tag_suffix_match
      Proc.new {|tag| "#{tag_prefix}#{rstrip.call(tag, tag_suffix_match)}#{tag_suffix}" }
    else
      Proc.new {|tag| "#{tag_prefix}#{tag}#{tag_suffix}" }
    end
  end

  def match(regexp, string)
    begin
      return regexp.match(string)
    rescue ArgumentError => e
      raise e unless @replace_invalid_sequence
      raise e unless e.message.index("invalid byte sequence in") == 0
      log.info "out_grep: invalid byte sequence is replaced in `#{string}`"
      string = string.scrub('?')
      retry
    end
    return true
  end
end
