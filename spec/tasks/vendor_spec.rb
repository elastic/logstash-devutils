require 'rspec'
require 'stringio'
require_relative '../../lib/logstash/devutils/rake/task_helpers'

describe TaskHelpers do
  describe 'release' do
     it "raises an error if the gemspec is not found" do
       expect{TaskHelpers.release("")}.to raise_error(Errno::ENOENT)
     end

     it "publishes a gem" do
       gem_file = "/tmp/file.gem"
       pub_return = "str"
       expect(GemPublisher).to receive(:publish_if_updated).with(gem_file, :rubygems).and_return(pub_return)
       expect(TaskHelpers.release(gem_file)).to equal(pub_return)
     end
  end

  describe 'vendor_files' do
    it "downloads a remote file" do
      url = "https://somewhere/database-1.1.2.txt"
      file_content = "content"; io = StringIO.new; io << file_content; io.rewind
      sha1 = Digest::SHA1.hexdigest file_content
      vendor_files = [{ "file" => url, "sha1" => sha1 }]

      expect(TaskHelpers).to receive(:open).with(url, "rb").and_return(io)
      expect(TaskHelpers).to receive(:calc_sha1).and_return(sha1)
      expect { TaskHelpers.vendor_files(vendor_files, "/tmp") }.to_not raise_error
    end

    it "raises exception if sha1 checking fails" do
      vendor_files = [{ "file" => "http://url/file.txt" , "sha1" => "34" }]
      expect(TaskHelpers).to receive(:download).
        with("http://url/file.txt", "vendor/").
        and_return(["vendor/file.txt", "33"])
      expect { TaskHelpers.vendor_files(vendor_files) }.to raise_error
    end

    it "pulls a sha1 checksum from url" do
      vendor_files = [
        {
          "file" => "http://url/file.txt",
          "sha1" => "http://url/sha1.txt"
        }
      ]
      sha1 = "d2ddd4bb206d1aae5a5dae88649ca2b7ce2c235b"
      expect(TaskHelpers).to receive(:download).with("http://url/file.txt", "vendor/").and_return(["vendor/file.txt", sha1])
      io = StringIO.new; io << sha1; io.rewind
      expect(TaskHelpers).to receive(:open).with(vendor_files.first['sha1']).and_return(io)
      expect { TaskHelpers.vendor_files(vendor_files) }.to_not raise_error
    end

    it "detects archives" do
      vendor_files = [ { "file" => "http://localhost/file", "sha1" => "34" } ]
      extensions = [".db", ".tar.gz", ".tgz", ".txt", ".tar", ".gz"]
      archive = [false, true, true, false, true, true]

      extensions.each_with_index do |ext, i|
        file_name = "http://localhost/file#{ext}"
        vendor_files.first["file"] = "http://localhost/file#{ext}"
        expect(TaskHelpers).to receive(:download).with(file_name, "vendor/").and_return(["vendor/file.#{ext}", "34"])
        expect(TaskHelpers).to receive(:extract).once if archive[i]
        expect { TaskHelpers.vendor_files(vendor_files) }.to_not raise_error
      end
    end
  end
end
