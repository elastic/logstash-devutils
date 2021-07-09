begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) # default glob: 'spec/**{,/*/**}/*_spec.rb'
rescue LoadError
end

desc "Run tests including Java tests (if any)"
task :test => :vendor do
  sh './gradlew test' if File.exist?('./gradlew')
  Rake::Task[:spec].invoke
end
