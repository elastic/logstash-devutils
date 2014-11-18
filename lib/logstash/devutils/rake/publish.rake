require "gem_publisher"

# gem_publisher uses Open3.capture3 to call git binary
# this does not work on jruby. Open3.popen3 works
if RUBY_PLATFORM == "java"
  module GemPublisher
    class CliFacade
      def execute(*arguments)
        cmd = Shellwords.join(arguments)
        puts cmd
        Open3.popen3(cmd) do |_i, stdout, stderr, thr|
          output = [stderr.read, stdout.read].join.strip
          raise Error, output if thr.value.exitstatus > 0
          return output
        end
      end
    end
  end
end

desc "Publish gem to RubyGems.org"
task :publish_gem do |t|
  gem_file = Dir.glob(File.expand_path('../*.gemspec',File.dirname(__FILE__))).first
  gem = GemPublisher.publish_if_updated(gem_file, :rubygems)
  puts "Published #{gem}" if gem
end

