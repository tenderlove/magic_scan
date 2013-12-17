require 'image'

class ReferenceImage < Image
  def self.create! attributes
    if hash = attributes.delete(:fingerprint)
      right  = hash & 0xFFFFFFFF
      left   = (hash >> 32) & 0xFFFFFFFF
      attributes[:fingerprint_l] = left
      attributes[:fingerprint_r] = right
    end
    super
  end

  def self.find_by_hash hash
    right  = hash & 0xFFFFFFFF
    left   = (hash >> 32) & 0xFFFFFFFF
    where(:fingerprint_r => right,
          :fingerprint_l => left).first
  end

  def self.find_similar hash, limit = 10
    all.sort_by { |rec|
      Phashion.hamming_distance rec.fingerprint, hash
    }.first limit
  end

  def fingerprint
    (fingerprint_l << 32) + fingerprint_r
  end
end
