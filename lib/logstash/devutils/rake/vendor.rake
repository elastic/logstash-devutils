raise "Only JRuby is supported at this time." unless RUBY_PLATFORM == "java"
require "net/http"
require "uri"
require "digest/sha1"

directory "vendor/" => ["vendor"] do |task, args|
  mkdir task.name
end

desc "Process any vendor files required for this plugin"
task "vendor" => [ "vendor:files" ]

namespace "vendor" do
  task "files" do
    # TODO(sissel): refactor the @files Rakefile ivar usage anywhere into 
    # the vendor.json stuff.
    utils = LogStash::DevUtils::Utils.new
    if @files
      @files.each do |file| 
        download = utils.file_fetch(file['url'], file['sha1'])
        if download =~ /.tar.gz/
          prefix = download.gsub('.tar.gz', '').gsub('vendor/', '')
          utils.untar(download) do |entry|
            if !file['files'].nil?
              next unless file['files'].include?(entry.full_name.gsub(prefix, ''))
              out = entry.full_name.split("/").last
            end
            File.join('vendor', out)
          end
        elsif download =~ /.gz/
          utils.ungz(download)
        end
      end
    end
  end
end
