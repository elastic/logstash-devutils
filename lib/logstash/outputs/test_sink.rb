# encoding: utf-8
require "logstash/namespace"
require "logstash/outputs/base"
require "logstash/errors"

# This output simply discards (but tracks) received events.
class LogStash::Outputs::TestSink < LogStash::Outputs::Base

  concurrency :shared

  config_name "test_sink"

  # Whether we're tracking events received or simply act as a true sink.
  config :store_events, :validate => :boolean, :default => true
  # Plugin could not release itself (on close) if needed to keep its events around.
  config :release_on_close, :validate => :boolean, :default => true

  TRACKER = java.util.WeakHashMap.new

  # @override plugin hook
  def register
    TRACKER[self] = java.util.concurrent.ConcurrentLinkedQueue.new
  end

  # @override plugin impl
  def receive(event)
    event_store << event if store_events?
  end

  # @override plugin hook
  def close
    TRACKER.delete(self) if release_on_close?
  end

  def store_events?
    !!@store_events
  end

  def release_on_close?
    !!@release_on_close
  end

  def clear!
    event_store.clear
  end

  def event_store
    TRACKER[self] || raise("#{self} not registered; please call plugin.register before use")
  end

end