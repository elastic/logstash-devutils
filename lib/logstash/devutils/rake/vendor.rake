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
task "vendor" => [ "vendor:files" ]

namespace "vendor" do
  task "files" do
    TaskHelpers.vendor_files JSON.parse(IO.read("vendor.json"))
  end
end
