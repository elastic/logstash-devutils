require 'gem_publisher'
require 'open-uri'
require 'uri'
require 'digest'
require 'zlib'
require 'archive/tar/minitar'

module TaskHelpers
  SHA1_REGEXP = /(\b[0-9a-f]{5,40}\b)/

  def self.release(gem_file)
    GemPublisher.publish_if_updated(gem_file, :rubygems)
  end

  # {
  #   "file" : "uri:///file.tar.gz",
  #   "sha1" : "uri:///sha1",
  #   "extract" : [ "src/data.db" ]
  # }
  def self.vendor_files(files, target_path = "vendor/")
    files.each do |file_manifest| 

      file_uri = file_manifest['file']
      expected_sha1 = file_manifest['sha1']

      file = fetch_file(file_uri, target_path, expected_sha1)

      if file && (archive?(file) || compressed?(file))
        extract(file, target_path, file_manifest['extract'])
        File.delete file
      end
    end
  end

  private

  def self.fetch_file(file_uri, target_path, sha1_uri = nil)
    file_name, file_sha1 = download(file_uri, target_path)
    validate_sha1(file_sha1, fetch_sha1(sha1_uri)) ? file_name : false
  end

  def self.extract(file, target, extract_list = {})
    tmp_dir = Dir.mktmpdir
    file = decompress(file, tmp_dir) if compressed?(file)
    if archive?(file)
      unpack(file, tmp_dir, extract_list.keys); File.delete(file)
      if extract_list.empty?
        FileUtils.cp_r("#{tmp_dir}/.", target)
      else
        move_files(extract_list, tmp_dir, target)
      end
    else # single file => move to target
      FileUtils.cp(file, target)
    end
    FileUtils.remove_entry_secure tmp_dir
  end

  def self.move_files(file_list, from, to)
    file_list.each { |src, dest| File.rename(File.join(from, src), File.join(to, dest)) }
  end

  def self.unpack(archive, target = ".", extract_list = [])
    Archive::Tar::Minitar.unpack(archive, target, extract_list)
  end

  def self.decompress(file_name, target = ".")
    output_file = File.join(target, File.basename(file_name)).sub(".gz", "").sub(".tgz", ".tar")

    Zlib::GzipReader.open(file_name) do |gz|
      File.open(output_file, "w") { |g| IO.copy_stream(gz, g) }
    end
    output_file
  end

  def self.archive?(file_name)
    /\.(tgz|tar|tar\.gz)$/ === file_name
  end

  def self.compressed?(file_name)
    /\.(tgz|gz|gz)$/ === file_name
  end

  def self.validate_sha1(sha1, reference_sha1)
    if reference_sha1.nil? || reference_sha1.empty?
      puts "Skipping sha1 checking since no reference checksum was given"
      return false
    end

    if sha1 == reference_sha1
      return true
    else
      raise Exception, "sha1 mismatch: got #{sha1} but expected #{reference_sha1}"
    end
  end

  def self.download(uri_str, path)
    destination = File.join(path, File.basename(URI(uri_str).path))

    File.open(destination, "wb") do |saved_file|
      open(uri_str, "rb") { |read_file| saved_file.write(read_file.read) }
    end

    [destination, calc_sha1(destination)]
  end

  def self.calc_sha1(file_name)
    Digest::SHA1.file(file_name).hexdigest
  end

  def self.fetch_sha1(uri_str)
    return uri_str if URI(uri_str.to_s).scheme.nil? # actual sha1
      
    match = open(uri_str).read.match(SHA1_REGEXP)
    
    if match
      return match[0]
    else
      raise Exception, "No sha1 found in \"#{uri_str}\", aborting.."
    end
  end
end
