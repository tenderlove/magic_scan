require 'magic_scan/database'

module MagicScan
  class Model
    attr_reader :id

    def initialize attributes
      @attributes = attributes.each_with_object({}) { |(k,v),o|
        o[k.to_s] = v
      }
      @id            = nil
    end

    def init_with_attrs id, attributes
      @id         = id
      @attributes = attributes.each_with_object({}) { |(k,v),o|
        o[k.to_s] = v
      }
    end

    def method_missing method, *args, &block
      @attributes.fetch(method.to_s) { super }
    end
  end

  class ReferenceCard < Model
    def save!
      sql = "INSERT INTO reference_cards #{@attributes.keys.sort.join(", ")}"
        " VALUES (#{@attributes.values.map { "?" }.join ", "})"

      Database.exec sql, @attributes.keys.sort.map { |k| @attributes[k] }
      @id = Database.connection.last_insert_row_id
      self
    end
  end

  class ReferenceImage < Model
    def self.create mvid, hash, filename
      right = hash & 0xFFFFFFFF
      left  = (hash >> 32) & 0xFFFFFFFF
      data = { :mv_id         => mvid,
               :fingerprint_l => left,
               :fingerprint_r => right,
               :filename      => filename }
      new data
    end

    def self.find_by_id id
      result = Database.exec "SELECT * FROM reference_images WHERE id = ?", id
      cols = result.columns
      row  = result.first
      instance = allocate
      data = Hash[cols.zip row]
      instance.init_with_attrs data['id'], data
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
      data = Hash[result.columns.zip row]
      instance.init_with_attrs data['id'], data
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

    def fingerprint
      (fingerprint_l << 32) + fingerprint_r
    end

    def save!
      sql = "INSERT INTO reference_images (#{@attributes.keys.sort.join(", ")})" \
        " VALUES (#{@attributes.values.map { "?" }.join ", "})"

      Database.exec sql, @attributes.keys.sort.map { |k| @attributes[k] }
      @id = Database.connection.last_insert_row_id
      self
    end
  end
end
