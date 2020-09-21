source 'https://rubygems.org'
gemspec

if Dir.exist?(logstash_path = ENV["LOGSTASH_PATH"])
  gem 'logstash-core', path: "#{logstash_path}/logstash-core"
  gem 'logstash-core-plugin-api', path: "#{logstash_path}/logstash-core-plugin-api"
end
