require "logstash/pipeline"
require "logstash/java_pipeline"

require "logstash/test_pipeline/pipeline_compat"

module LogStash
  class TestPipeline < LogStash::JavaPipeline
    public :flush_filters

    attr_reader :test_read_client

    def run_with(events)
      if inputs&.any? # will work but might be unintended
        config = "\n #{config_str}" if $VERBOSE
        warn "#{self} pipeline is getting events pushed manually while having inputs: #{inputs.inspect}  #{config}"
      end
      # TODO could we handle an generator (Enumerator) ?
      queue.write_client.push_batch events.to_a
      @test_read_client = EventTrackingQueueReadClientDelegator.new filter_queue_client
      run
    end

    # @override
    def worker_loop
      read_client = @test_read_client || filter_queue_client
      WorkerLoop.new(lir_execution, read_client, @events_filtered, @events_consumed,
                     @flushRequested, @flushing, @shutdownRequested, @drain_queue).run

      super
    end

    class EventTrackingQueueReadClientDelegator
      include org.logstash.execution.QueueReadClient
      java_import org.logstash.execution.QueueReadClient

      attr_reader :processed_events

      def initialize(delegate)
        # NOTE: can not use LogStash::MemoryReadClient#read_batch due its JavaObject wrapping
        @delegate = delegate.to_java(QueueReadClient)
        @processed_events = []
      end

      # @override QueueBatch readBatch() throws InterruptedException;
      def readBatch
        QueueBatchDelegator.new(self, @delegate.read_batch)
      end

      # @override void closeBatch(QueueBatch batch) throws IOException;
      def closeBatch(batch)
        @delegate.close_batch(batch)
      end

      # @override boolean isEmpty();
      def isEmpty
        @delegate.empty?
      end

      # @override QueueBatch newBatch();
      def newBatch
        @delegate.new_batch
      end

      # @override void startMetrics(QueueBatch batch);
      def startMetrics(batch)
        @delegate.start_metrics(batch)
      end

      # @override void addOutputMetrics(int filteredSize);
      def addOutputMetrics(filteredSize)
        @delegate.add_output_metrics(filteredSize)
      end

      # @override void addFilteredMetrics(int filteredSize);
      def addFilteredMetrics(filteredSize)
        @delegate.add_filtered_metrics(filteredSize)
      end

      def filtered_events(events)
        @processed_events.concat(events)
      end

    end

    class QueueBatchDelegator
      include org.logstash.execution.QueueBatch

      def initialize(event_tracker, delegate)
        @event_tracker = event_tracker
        @delegate = delegate
      end

      # @override RubyArray to_a();
      def to_a
        @delegate.to_a.tap do |events|
          # filters out rogue (cancelled) events
          @event_tracker.filtered_events events
        end
      end

      # @override int filteredSize();
      def filteredSize
        @delegate.to_java.filtered_size
      end

      # @override void merge(IRubyObject event);
      def merge(event)
        @delegate.merge(event)
      end

      # @override void close() throws IOException;
      def close
        @delegate.close
      end

    end
  end
end
