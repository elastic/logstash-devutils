## 2.6.2
 - Fix: in case of redirected HTTP downloads, return the hash code of the downloaded artifact. [#106](https://github.com/elastic/logstash-devutils/pull/106)
 - Fix: changed the prefix extraction from tar.gz name to the extracted folder name. [#109](https://github.com/elastic/logstash-devutils/pull/109) 

## 2.6.1
 - Fix: updated implementation of downloading of vendored artifacts to follow HTTP redirections. [#105](https://github.com/elastic/logstash-devutils/pull/105)

## 2.6.0
- Removed SimpleCov configuration, as it will be moved directly to elastic/logstash [#103](https://github.com/elastic/logstash-devutils/pull/103)

## 2.5.0
 - Bumped kramdown dependency to "~> 2"

## 2.4.0
 - Feat: shared test (spec) task for all! [#96](https://github.com/elastic/logstash-devutils/pull/96)

## 2.3.0
 - Introduce `be_a_logstash_timestamp_equivalent_to` RSpec matcher to compare LogStash::Timestamp [#99](https://github.com/elastic/logstash-devutils/pull/99)

## 2.2.1
 - Fixed `LogStashHelpers#sample` to work with pipelines whose filters add, clone, and cancel events.

## 2.2.0
 - Add `allowed_lag` config for shared input interruptiblity spec

## 2.1.0
 - Remove ruby pipeline dependency

## 2.0.4
 - Fix: avoid double registering filters on `sample` spec helper

## 2.0.3
 - Fix: add missing `events` method to QueuedBatchDelegator, which was causing test failures
 after https://github.com/elastic/logstash/pull/11737 was committed.

## 2.0.2
 - Fix: add plain codec as runtime dependency for TestPipeline helper

## 2.0.1
 - Fix: unwrap output and refactor test sink (#82)

## 2.0.0
 - Reinvented helpers using Java pipeline, only LS >= 6.x (JRuby >= 9.1) is supported.
 - [BREAKING] changes:
   * `plugin_input` helper no longer works - simply fails with a not implemented error
   * `type` and `tags` helpers have no effect - they will print a deprecation warning
   * using gem **insist** is discouraged and has to be pulled in manually
     (in *plugin.gemspec* `add_development_dependency 'insist'` and `require "insist"`)
   * shared examples need to be explicitly required, as they are not re-used that much
     (in spec_helper.rb `require "logstash/devutils/rspec/shared_examples"'`)
   * `input` helper now yields a Queue-like collection (with `Queue#pop` blocking semantics)
     with a default timeout polling mechanism to guard against potential dead-locks

## 1.3.6
 - Revert the removal (e.g. add back) of the log4j spec helper. It is still needed for 5.x builds.

## 1.3.5
 - Fix spec helper method `input` generating an invalid `output_func` that returned `nil` instead of an array
 - Remove spec helper log4j explicit initialization and rely on logstash-core default log4j initialization

## 1.3.4
 - Pin kramdown gem to support ruby 1.x syntax for LS 5.x

## 1.3.3
 - Make input function support different pipeline constructor signatures - for compatibility with logstash-core 6.0
 - Make return of lambda used in input helpers explicit

## 1.3.2
 - Make sample function support different pipeline constructor signatures - for compatibility with logstash-core 6.0

## 1.3.1
 - Close pipeline after #sample helper - for compatibility with logstash-core 5.3

## 1.3.0
 - Temporary add more visibility into the pipeline to make the #sample method work

## 1.2.1
 - require logstash-core gem manually to make all the jars available to the plugin unit tests
