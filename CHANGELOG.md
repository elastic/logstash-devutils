## 1.3.5
 - Fix spec helper method `input` generating an invalid `output_func` that returned `nil` instead of an array

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
