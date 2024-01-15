require "logstash-core"
require "logstash/logging"
require "logstash/devutils/rspec/logstash_helpers"

Thread.abort_on_exception = true

# set log4j configuration
unless java.lang.System.getProperty("log4j.configurationFile")
  log4j2_properties = "#{File.dirname(__FILE__)}/log4j2.properties"
  LogStash::Logging::Logger::initialize("file:///" + log4j2_properties)
end

$TESTING = true
if RUBY_VERSION < "2.3"
  raise LoadError.new("Ruby >= 2.3.0 or later is required. (You are running: " + RUBY_VERSION + ")")
end

if level = (ENV['LOG_LEVEL'] || ENV['LOGGER_LEVEL'] || ENV["TEST_DEBUG"])
  logger, level = level.split('=') # 'logstash.filters.grok=DEBUG'
  level, logger = logger, nil if level.nil? # only level given e.g. 'DEBUG'
  level = org.apache.logging.log4j.Level.toLevel(level, org.apache.logging.log4j.Level::WARN)
  LogStash::Logging::Logger::configure_logging(level.to_s, logger)
else
  LogStash::Logging::Logger::configure_logging('ERROR')
end

RSpec::Matchers.define :be_a_logstash_timestamp_equivalent_to do |expected|
  # use the Timestamp compare to avoid suffering of precision loss of time format
  expected = LogStash::Timestamp.new(expected) unless expected.kind_of?(LogStash::Timestamp)
  description { "be a LogStash::Timestamp equivalent to #{expected}" }

  match do |actual|
    actual.kind_of?(LogStash::Timestamp) && actual == expected
  end
end

RSpec.configure do |config|
  # for now both include and extend are required because the newly refactored "input" helper method need to be visible in a "it" block
  # and this is only possible by calling include on LogStashHelper
  config.include LogStashHelper
  config.extend LogStashHelper

  config.filter_run_excluding LogStashHelper.excluded_tags

  config.around(:each) do |example|
    @__current_example_metadata = example.metadata
    example.run
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random
end
