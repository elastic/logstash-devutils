require "logstash/agent"
require "logstash/pipeline"
require "logstash/event"
require "stud/try"
require "rspec/expectations"

class LogStash::JavaPipeline

  unless instance_methods(false).include?(:worker_loop)

    # NOTE: copy-pasta from LS - to define the #worker_loop hook the TestPipeline relies upon.
    def start_workers
      @worker_threads.clear # In case we're restarting the pipeline
      @outputs_registered.make_false
      begin
        maybe_setup_out_plugins

        pipeline_workers = safe_pipeline_worker_count
        batch_size = settings.get("pipeline.batch.size")
        batch_delay = settings.get("pipeline.batch.delay")

        max_inflight = batch_size * pipeline_workers

        config_metric = metric.namespace([:stats, :pipelines, pipeline_id.to_s.to_sym, :config])
        config_metric.gauge(:workers, pipeline_workers)
        config_metric.gauge(:batch_size, batch_size)
        config_metric.gauge(:batch_delay, batch_delay)
        config_metric.gauge(:config_reload_automatic, settings.get("config.reload.automatic"))
        config_metric.gauge(:config_reload_interval, settings.get("config.reload.interval"))
        config_metric.gauge(:dead_letter_queue_enabled, dlq_enabled?)
        config_metric.gauge(:dead_letter_queue_path, dlq_writer.get_path.to_absolute_path.to_s) if dlq_enabled?
        config_metric.gauge(:ephemeral_id, ephemeral_id)
        config_metric.gauge(:hash, lir.unique_hash)
        config_metric.gauge(:graph, ::LogStash::Config::LIRSerializer.serialize(lir))
        config_metric.gauge(:cluster_uuids, resolve_cluster_uuids)

        pipeline_log_params = default_logging_keys(
            "pipeline.workers" => pipeline_workers,
            "pipeline.batch.size" => batch_size,
            "pipeline.batch.delay" => batch_delay,
            "pipeline.max_inflight" => max_inflight,
            "pipeline.sources" => pipeline_source_details)
        @logger.info("Starting pipeline", pipeline_log_params)

        if max_inflight > MAX_INFLIGHT_WARN_THRESHOLD
          @logger.warn("CAUTION: Recommended inflight events max exceeded! Logstash will run with up to #{max_inflight} events in memory in your current configuration. If your message sizes are large this may cause instability with the default heap size. Please consider setting a non-standard heap size, changing the batch size (currently #{batch_size}), or changing the number of pipeline workers (currently #{pipeline_workers})", default_logging_keys)
        end

        filter_queue_client.set_batch_dimensions(batch_size, batch_delay)

        pipeline_workers.times do |t|
          thread = Thread.new do
            Util.set_thread_name("[#{pipeline_id}]>worker#{t}")
            ThreadContext.put("pipeline.id", pipeline_id)
            worker_loop #
          end
          @worker_threads << thread
        end

        begin
          start_inputs
        rescue => e
          shutdown_workers
          raise e
        end
      ensure
        @ready.make_true
      end
    end

    java_import org.logstash.execution.WorkerLoop

    def worker_loop
      WorkerLoop.new(lir_execution, filter_queue_client, @events_filtered, @events_consumed,
                     @flushRequested, @flushing, @shutdownRequested, @drain_queue).run
    end
  end

end

require "logstash/environment"

module LogStashHelper

  @@excluded_tags = {
      :integration => true,
      :redis => true,
      :socket => true,
      :performance => true,
      :couchdb => true,
      :elasticsearch => true,
      :elasticsearch_secure => true,
      :export_cypher => true
  }

  if LogStash::Environment.windows?
    @@excluded_tags[:unix] = true
  else
    @@excluded_tags[:windows] = true
  end

  def self.excluded_tags
    @@excluded_tags
  end

  class TestPipeline < LogStash::JavaPipeline
    public :flush_filters

    attr_reader :test_read_client

    def run_with(events)
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

  DEFAULT_NUMBER_OF_TRY = 5
  DEFAULT_EXCEPTIONS_FOR_TRY = [RSpec::Expectations::ExpectationNotMetError]

  def try(number_of_try = DEFAULT_NUMBER_OF_TRY, &block)
    Stud.try(number_of_try.times, DEFAULT_EXCEPTIONS_FOR_TRY, &block)
  end

  def config(configstr)
    let(:config) { configstr }
  end # def config

  def type(default_type)
    deprecated "type(#{default_type.inspect}) no longer has any effect"
  end

  def tags(*tags)
    let(:default_tags) { tags }
    deprecated "tags(#{tags.inspect}) - let(:default_tags) are not used"
  end

  def sample(sample_event, &block)
    name = sample_event.is_a?(String) ? sample_event : LogStash::Json.dump(sample_event)
    name = name[0..50] + "..." if name.length > 50

    describe "\"#{name}\"" do
      let(:pipeline) { new_pipeline_from_string(config) }
      let(:event) do
        sample_event = [sample_event] unless sample_event.is_a?(Array)
        next sample_event.collect do |e|
          e = { "message" => e } if e.is_a?(String)
          next LogStash::Event.new(e)
        end
      end

      let(:results) do
        pipeline.filters.each(&:register)

        pipeline.run_with(event)

        # flush makes sure to empty any buffered events in the filter
        pipeline.flush_filters(:final => true) { |flushed_event| results << flushed_event }

        pipeline.test_read_client.processed_events
      end

      # starting at logstash-core 5.3 an initialized pipeline need to be closed
      after do
        pipeline.close if pipeline.respond_to?(:close)
      end

      subject { results.length > 1 ? results : results.first }

      it("when processed", &block)
    end
  end # def sample

  def input(config, &block)
    pipeline = new_pipeline_from_string(config)
    queue = Queue.new

    pipeline.instance_eval do
      # create closure to capture queue
      @output_func = lambda { |event| queue << event }

      # output_func is now a method, call closure
      def output_func(event)
        @output_func.call(event)
        # We want to return nil or [] since outputs aren't used here
        []
      end
    end

    pipeline_thread = Thread.new { pipeline.run }
    sleep 0.01 while !pipeline.ready?

    result = block.call(pipeline, queue)

    pipeline.shutdown
    pipeline_thread.join

    result
  end # def input

  def plugin_input(plugin, &block)
    queue = Queue.new

    input_thread = Thread.new do
      plugin.run(queue)
    end
    result = block.call(queue)

    plugin.do_stop
    input_thread.join
    result
  end

  def agent(&block)

    it("agent(#{caller[0].gsub(/ .*/, "")}) runs") do
      pipeline = new_pipeline_from_string(config)
      pipeline.run # TODO
      block.call
    end
  end # def agent

  def new_pipeline_from_string(string)
    # if TestPipeline.instance_methods.include?(:pipeline_config)
      settings = ::LogStash::SETTINGS.clone

      config_part = org.logstash.common.SourceWithMetadata.new("config_string", "config_string", string)

      pipeline_config = LogStash::Config::PipelineConfig.new(LogStash::Config::Source::Local, :main, config_part, settings)
      TestPipeline.new(pipeline_config)
    # else
    #   TestPipeline.new(string)
    # end
  end

  private

  if RUBY_VERSION > '2.5'
    def deprecated(msg)
      Kernel.warn(msg, uplevel: 2)
    end
  else # due JRuby 9.1 (Ruby 2.3)
    def deprecated(msg)
      loc = caller_locations[2]
      Kernel.warn("#{loc.path}:#{loc.lineno}: warning: #{msg}")
    end
  end

end # module LogStash

