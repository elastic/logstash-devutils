class LogStash::Event
  alias_method :setval, :[]=
  def []=(str, value)
    if str == TIMESTAMP && !value.is_a?(LogStash::Timestamp)
      raise TypeError, "The field '@timestamp' must be a LogStash::Timestamp, not a #{value.class} (#{value})"
    end
    LogStash::Event.validate_value(value)
    setval(str, value)
  end # def []=
end
