require 'magic_scan/database'

module MagicScan
  class ReferenceImage
    attr_reader :mvid, :filename, :id

    def self.create mvid, hash, filename
      right = hash & 0xFFFFFFFF
      left  = (hash >> 32) & 0xFFFFFFFF
      new mvid, left, right, filename
    end

    def self.find_by_id id
      result = Database.exec "SELECT * FROM reference_images WHERE id = ?", id
      cols = result.columns
      row  = result.first
      instance = allocate
      instance.init_with_hash Hash[cols.zip row]
      instance
    end

    def self.find_by_hash hash
      right  = hash & 0xFFFFFFFF
      left   = (hash >> 32) & 0xFFFFFFFF
      result = Database.exec "SELECT * FROM reference_images
                            WHERE fingerprint_l = ? AND fingerprint_r = ?",
                            [left, right]

      row      = result.first
      instance = allocate
      instance.init_with_hash Hash[result.columns.zip row]
      instance
    end

    def self.find_with_matching_hash hash
      result = Database.exec "SELECT id, fingerprint_l, fingerprint_r
                                  FROM reference_images"
      row = result.min_by do |id, left, right|
        row_hash = (left << 32) + right
        Phashion.hamming_distance hash, row_hash
      end
      _, left, right = row
      row_hash = (left << 32) + right
      return nil unless Phashion.hamming_distance(hash, row_hash) < 15
      find_by_id row.first
    end

    def initialize mvid, fingerprint_l, fingerprint_r, filename
      @mvid          = mvid
      @fingerprint_l = fingerprint_l
      @fingerprint_r = fingerprint_r
      @filename      = filename
      @id            = nil
    end

    def init_with_hash hash
      hash.each_pair { |k,v| instance_variable_set :"@#{k}", v }
    end

    def fingerprint
      (@fingerprint_l << 32) + @fingerprint_r
    end

    def save!
      Database.exec "INSERT INTO reference_images
                  (mv_id, fingerprint_l, fingerprint_r, filename) VALUES (?, ?, ?, ?)",
                  [@mvid, @fingerprint_l, @fingerprint_r, @filename]
      @id = Database.connection.last_insert_row_id
    end
  end
end
