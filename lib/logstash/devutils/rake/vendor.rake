raise "Only JRuby is supported at this time." unless RUBY_PLATFORM == "java"
require 'json'
require_relative "task_helpers"

def vendor(*args)
  return File.join("vendor", *args)
end

directory "vendor/" => ["vendor"] do |task, args|
  mkdir task.name
end

desc "Process any vendor files required for this plugin"
task "vendor" => [ "vendor:files", "vendor:jars" ]

namespace "vendor" do
  task "files" do
    TaskHelpers.vendor_files JSON.parse(IO.read("vendor.json"))
  end

  task "jars" do
    # Skip jars work on non-java platforms.
    next unless RUBY_PLATFORM == "java"
    require 'jar_installer'
    # Find all gems that have jar dependencies.
    # This is notable by the Gem::Specification#requirements having an entry
    # that starts with "jar "
    Gem::Specification.find_all.select { |gem| gem.requirements.any? { /^jar / } }.each do |gem|
      puts "Fetching jar dependencies for #{gem.name}"
      Jars::JarInstaller.new(gem).vendor_jars
    end
  end

end
