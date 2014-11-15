# encoding: utf-8
require "logstash/devutils/rspec/helpers"

# Methods used in setting up things for rspec.
module LogStash::DevUtils::Rspec
  def self.setup_coveralls
    require 'simplecov'
    require 'coveralls'

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
    SimpleCov.start do
      add_filter 'spec/'
      add_filter 'vendor/'
    end
  end # def self.setup_coveralls
 
  def self.setup_logger
    logger = LogStash::Logger.new(STDOUT)
    if ENV["TEST_DEBUG"]
      logger.level = :debug
    else
      logger.level = :error
    end
  end # def self.setup_logger

  def self.monkeypatch
    monkeypatch_logstash_event
  end # def self.monkeypatch

  # Make LogStash::Event#[]= do additional validation.
  #
  # This is roughly equivalent in intent to Java 'assert' in that costly
  # validation can be disabled for production, but enabled to check invariants
  # and other conditions during testing and development.
  def self.monkeypatch_logstash_event
    require "logstash/devutils/rspec/monkeypatch_logstash_event"
  end # def self.monkeypatch_logstash_event

  DEFAULT_RSPEC_EXCLUDES = { :redis => true, :socket => true, :performance => true, :elasticsearch => true, :broken => true, :export_cypher => true }
  def self.configure_rspec
    RSpec.configure do |config|
      config.extend LogStash::DevUtils::RSpec::Helpers
      config.filter_run_excluding(DEFAULT_RSPEC_EXCLUDES)
    end
  end # def self.configure_rspec
end # module LogStash::DevUtils::RSpec

LogStash::DevUtils::RSpec.setup_coveralls if ENV["COVERAGE"]
