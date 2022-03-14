begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) # default glob: 'spec/**{,/*/**}/*_spec.rb'
rescue LoadError
end

desc "Run tests including Java tests (if any)"
task :test => [ 'test:java', 'test:ruby' ]
namespace :test do
  task :java do
    gradlew = File.join(Dir.pwd, 'gradlew')
    sh "#{gradlew} --no-daemon test" if File.exist?(gradlew)
  end
  task :ruby => :vendor do
    Rake::Task[:spec].invoke
  end
end
