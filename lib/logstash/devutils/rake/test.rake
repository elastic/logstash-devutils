begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) # default glob: 'spec/**{,/*/**}/*_spec.rb'
rescue LoadError
end

desc "Run tests including Java tests (if any)"
task :test do
  gradlew = File.join(Dir.pwd, 'gradlew')
  sh "#{gradlew} --no-daemon test" if File.exist?('gradlew')

  # Gradle assumes tests need a clean built so it will `clean` as part
  # of the `test` task -> any built .jar or copyied files get deleted
  # thus this isn't a `task :test => :vendor` dependency.
  Rake::Task[:vendor].invoke

  Rake::Task[:spec].invoke
end
