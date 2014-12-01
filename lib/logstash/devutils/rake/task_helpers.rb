require "gem_publisher"
require "open-uri"
require "uri"
require "digest"

module TaskHelpers

  SHA1_REGEXP = /(\b[0-9a-f]{5,40}\b)/

  def self.release gem_file
    GemPublisher.publish_if_updated(gem_file, :rubygems)
  end

  # {
  #   "file" : "uri:///file.tar.gz",
  #   "sha1" : "uri:///sha1",
  #   "extract" : [ "src/data.db" ]
  # }
  def self.vendor_files files, target_path="vendor/"
    files.each do |file_manifest| 

      file = fetch_file(file_manifest['file'], target_path, file_manifest['sha1'])

      if file && archive?(file)
        extract(file, target_path, file_manifest['extract'])
      end
    end
  end

  private
  def self.fetch_file file_uri, target_path, sha1=nil
    file_name, file_sha1 = download(file_uri, target_path)
    validate_sha1(file_sha1, fetch_sha1(sha1)) ? file_name : false
  end

  private
  def self.extract(file_name, target, extract_list)
    []
  end

  private
  def self.archive?(file_name)
    file_name.match(/(.tgz|.tar|.tar.gz|.gz)$/)
  end

  private
  def self.validate_sha1 sha1, reference_sha1
    if reference_sha1.nil? || reference_sha1.empty?
      Logger.warn "Skipping sha1 checking since no reference checksum was given"
      return false
    end

    if sha1 == reference_sha1 then
      return true
    else
      raise Exception, "sha1 mismatch: got #{sha1} but expected #{reference_sha1}"
    end
  end

  private
  def self.download uri_str, path

    destination = File.join(path, File.basename(URI(uri_str).path))

    File.open(destination, "wb") do |saved_file|
      open(uri_str, "rb") { |read_file| saved_file.write(read_file.read) }
    end

    [destination, calc_sha1(destination)]
  end

  private
  def self.calc_sha1 file_name
    Digest::SHA1.file(file_name).hexdigest
  end

  private
  def self.fetch_sha1 uri_str

    return uri_str if URI(uri_str).scheme.nil? # actual sha1
      
    match = open(uri_str).read.match(SHA1_REGEXP)
    
    if match then
      return match[0]
    else
      raise Exception, "No sha1 found in \"#{uri_str}\", aborting.."
    end
  end
end
