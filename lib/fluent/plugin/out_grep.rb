class Fluent::GrepOutput < Fluent::Output
  Fluent::Plugin.register_output('grep', self)

  config_param :input_key, :string
  config_param :regexp, :string, :default => nil
  config_param :exclude, :string, :default => nil
  config_param :tag, :string, :default => nil
  config_param :add_tag_prefix, :string, :default => 'greped'
  config_param :remove_tag_prefix, :string, :default => nil
  config_param :replace_invalid_sequence, :bool, :default => false

  def configure(conf)
    super

    @input_key = @input_key.to_s
    @regexp = Regexp.compile(@regexp) if @regexp
    @exclude = Regexp.compile(@exclude) if @exclude
    @tag_prefix = "#{@add_tag_prefix}."
    @tag_prefix_match = "#{@remove_tag_prefix}." if @remove_tag_prefix

    @tag_proc =
      if @tag
        Proc.new {|tag| @tag }
      elsif @tag_prefix and @tag_prefix_match
        Proc.new {|tag| "#{@tag_prefix}#{lstrip(tag, @tag_prefix_match)}" }
      elsif @tag_prefix_match
        Proc.new {|tag| lstrip(tag, @tag_prefix_match) }
      elsif @tag_prefix
        Proc.new {|tag| "#{@tag_prefix}#{tag}" }
      else
        Proc.new {|tag| tag }
      end
  end

  def emit(tag, es, chain)
    emit_tag = @tag_proc.call(tag)

    es.each do |time,record|
      value = record[@input_key]
      next unless match(value.to_s)
      Fluent::Engine.emit(emit_tag, time, record)
    end

    chain.next
  rescue => e
    $log.warn e.message
    $log.warn e.backtrace.join(', ')
  end

  private

  def lstrip(string, substring)
    string.index(substring) == 0 ? string[substring.size..-1] : string
  end

  def match(string)
    begin
      return false if @regexp and !@regexp.match(string)
      return false if @exclude and @exclude.match(string)
    rescue ArgumentError => e
      raise e unless e.message.index("invalid byte sequence in") == 0
      string = replace_invalid_byte(string)
      retry
    end
    return true
  end

  def replace_invalid_byte(string)
    replace_options = { invalid: :replace, undef: :replace, replace: '?' }
    original_encoding = string.encoding
    temporal_encoding = (original_encoding == Encoding::UTF_8 ? Encoding::UTF_16BE : Encoding::UTF_8)
    string.encode(temporal_encoding, original_encoding, replace_options).encode(original_encoding)
  end

end
