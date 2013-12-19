require 'fileutils'

class Image < ActiveRecord::Base
  has_and_belongs_to_many :cards

  after_destroy :rm_image

  def rm_image
    FileUtils.rm filename
  end

  def self.create! attributes
    if hash = attributes.delete(:fingerprint)
      right  = hash & 0xFFFFFFFF
      left   = (hash >> 32) & 0xFFFFFFFF
      attributes[:fingerprint_l] = left
      attributes[:fingerprint_r] = right
    end
    super
  end

  def self.build attributes
    if hash = attributes.delete(:fingerprint)
      right  = hash & 0xFFFFFFFF
      left   = (hash >> 32) & 0xFFFFFFFF
      attributes[:fingerprint_l] = left
      attributes[:fingerprint_r] = right
    end
    new attributes
  end

  def self.find_by_hash hash
    right  = hash & 0xFFFFFFFF
    left   = (hash >> 32) & 0xFFFFFFFF
    where(:fingerprint_r => right,
          :fingerprint_l => left).first
  end

  def self.find_similar hash, limit = 10
    right  = hash & 0xFFFFFFFF
    left   = (hash >> 32) & 0xFFFFFFFF

    select("*, hamming_distance(fingerprint_l, fingerprint_r, #{left}, #{right}) as distance")
      .includes(:cards)
      .order("distance ASC")
      .limit(3)
  end

  def self.find_similar_to_file file
    find_similar Phashion.image_hash_for file
  end

  def fingerprint
    (fingerprint_l << 32) + fingerprint_r
  end
end
