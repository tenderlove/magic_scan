require 'image'
require 'tempfile'

class UserImage < Image
  def self.build_from_bytes bytes
    tf = Tempfile.open self.name
    tf.binmode
    tf.write bytes
    tf.flush
    fingerprint = Phashion.image_hash_for tf.path
    tf.close
    tf.unlink

    build_with_hash_and_bytes fingerprint, bytes
  end

  def self.build_with_hash_and_bytes fingerprint, bytes
    digest = Digest::MD5.hexdigest bytes
    dest_dir = File.join 'app', 'assets', 'images', digest[0,2]
    dest_file = File.join dest_dir, "#{digest}.jpg"
    File.open(dest_file, 'wb') { |f| f.write bytes }

    build(:fingerprint => fingerprint,
           :filename    => dest_file)
  end
end
