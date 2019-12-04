
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
            worker_loop # all the fuzz due extracting this one
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
