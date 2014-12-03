require 'rspec'
require 'stringio'
require 'tmpdir'
require_relative '../../lib/logstash/devutils/rake/task_helpers'

module Helpers
  def generate_io_with(content)
    io = StringIO.new; io << content; io.rewind
    io
  end
end

describe TaskHelpers do
  include Helpers

  describe 'release' do
    it 'raises an error if the gemspec is not found' do
      expect { TaskHelpers.release('') }.to raise_error(Errno::ENOENT)
    end

    it 'publishes a gem' do
      gem_file = '/tmp/file.gem'
      pub_return = 'str'
      expect(GemPublisher).to receive(:publish_if_updated).with(gem_file, :rubygems).and_return(pub_return)
      expect(TaskHelpers.release(gem_file)).to equal(pub_return)
    end
  end

  describe 'vendor_files' do

    let(:tmp_dir) { Dir.mktmpdir }

    after do
      FileUtils.remove_entry_secure tmp_dir
    end

    it 'downloads a remote file' do
      url = 'https://somewhere/database-1.1.2.txt'
      file_content = 'content'; io = generate_io_with(file_content)
      sha1 = Digest::SHA1.hexdigest file_content
      vendor_files = [{ 'file' => url, 'sha1' => sha1 }]

      expect(TaskHelpers).to receive(:open).with(url, 'rb').and_return(io)
      expect(TaskHelpers).to receive(:calc_sha1).and_return(sha1)
      expect { TaskHelpers.vendor_files(vendor_files, '/tmp') }.to_not raise_error
    end

    it 'does not need a sha1 key or value' do
      vendor_files = [
        { 'file' => 'http://url/file.txt', 'sha1' => '' },
        { 'file' => 'http://url/file2.txt' }
      ]
      expect(TaskHelpers).to receive(:download).twice.and_return(['vendor/file.txt', '33'], ['vendor/file2.txt', '34'])
      expect(TaskHelpers).to receive(:puts).twice
      expect { TaskHelpers.vendor_files(vendor_files, '/tmp') }.to_not raise_error
    end

    it 'raises exception if sha1 checking fails' do
      vendor_files = [{ 'file' => 'http://url/file.txt', 'sha1' => '34' }]
      expect(TaskHelpers).to receive(:download).and_return(['vendor/file.txt', '33'])
      expect { TaskHelpers.vendor_files(vendor_files) }.to raise_error
    end

    it 'pulls a sha1 checksum from url' do
      vendor_files = [
        {
          'file' => 'http://url/file.txt',
          'sha1' => 'http://url/sha1.txt'
        }
      ]
      sha1 = 'd2ddd4bb206d1aae5a5dae88649ca2b7ce2c235b'
      expect(TaskHelpers).to receive(:download).with('http://url/file.txt', 'vendor/').and_return(['vendor/file.txt', sha1])
      io = generate_io_with(sha1)
      expect(TaskHelpers).to receive(:open).with(vendor_files.first['sha1']).and_return(io)
      expect { TaskHelpers.vendor_files(vendor_files) }.to_not raise_error
    end

    it 'detects archive vendor files using their extension' do
      vendor_files = [{ 'file' => 'http://localhost/file', 'sha1' => '34' }]
      extensions = ['.db', '.tar.gz', '.tgz', '.txt', '.tar', '.gz']
      archive = [false, true, true, false, true, true]

      extensions.each_with_index do |ext, i|
        file_name = "http://localhost/file#{ext}"
        vendor_files.first['file'] = file_name
        expect(TaskHelpers).to receive(:download).with(file_name, 'vendor/')
          .and_return(["vendor/file#{ext}", '34'])
        if archive[i]
          expect(TaskHelpers).to receive(:extract).once
          expect(File).to receive(:delete).once
        end
        expect { TaskHelpers.vendor_files(vendor_files) }.to_not raise_error
      end
    end

    it 'decompresses gzip files' do
      vendor_files = [
        {
          'file' => 'spec/fixtures/test.txt.gz',
          'sha1' => '738759749e8e49d984df7f00ec1d3f4cb8c2b03a'
        }
      ]
      expect { TaskHelpers.vendor_files(vendor_files, tmp_dir) }.to_not raise_error
      expect(Dir.glob(File.join(tmp_dir, '*'))).to eq([File.join(tmp_dir, 'test.txt')])
    end

    it 'unpacks archives' do
      vendor_files = [
        {
          'file' => 'spec/fixtures/archive.tar.gz',
          'sha1' => '081651050507462e0bea515145dc5925ee120891',
          'extract' => {
            'archive/dir1/file1.txt' => 'ola.tzt'
          }
        }
      ]
      expect { TaskHelpers.vendor_files(vendor_files, tmp_dir) }.to_not raise_error
      expect(Dir.glob(File.join(tmp_dir, '*'))).to eq([File.join(tmp_dir, 'ola.tzt')])
    end
  end
end
