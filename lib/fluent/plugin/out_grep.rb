class Fluent::GrepOutput < Fluent::Output
  Fluent::Plugin.register_output('grep', self)

  config_param :input_key, :string
  config_param :regexp, :string, :default => nil
  config_param :exclude, :string, :default => nil
  config_param :tag, :string, :default => nil
  config_param :add_tag_prefix, :string, :default => 'greped'
  config_param :replace_invalid_sequence, :bool, :default => false

  def configure(conf)
    super

    @input_key = @input_key.to_s
    @regexp = Regexp.compile(@regexp) if @regexp
    @exclude = Regexp.compile(@exclude) if @exclude
  end

  def emit(tag, es, chain)
    emit_tag = @tag ? @tag : "#{@add_tag_prefix}.#{tag}"

    es.each do |time,record|
      value = record[@input_key]
      next unless match(value)
      Fluent::Engine.emit(emit_tag, time, record)
    end

    chain.next
  rescue => e
    $log.warn e.message
    $log.warn e.backtrace.join(', ')
  end

  private

  def match(string)
    begin
      return false if @regexp and !@regexp.match(string)
      return false if @exclude and @exclude.match(string)
    rescue ArgumentError => e
      unless e.message.index("invalid byte sequence in") == 0
        raise
      end
      string = replace_invalid_byte(string)
      return false if @regexp and !@regexp.match(string)
      return false if @exclude and @exclude.match(string)
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
