class Fluent::GrepOutput < Fluent::Output
  Fluent::Plugin.register_output('grep', self)

  config_param :input_key, :string
  config_param :regexp, :string, :default => nil
  config_param :exclude, :string, :default => nil
  config_param :tag, :string, :default => nil
  config_param :add_tag_prefix, :string, :default => 'grep'

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
      next if @regexp and !@regexp.match(value)
      next if @exclude and @exclude.match(value)
      Fluent::Engine.emit(emit_tag, time, record)
    end

    chain.next
  end
end
