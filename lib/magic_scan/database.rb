module MagicScan
  module Database
    class Connection
      def initialize database
        @conn       = SQLite3::Database.new database
        @stmt_cache = {}
      end

      def execute sql, binds
        cache = @stmt_cache[sql] ||= {
          :stmt => @conn.prepare(sql)
        }
        stmt = cache[:stmt]
        cols = cache[:cols] ||= stmt.columns.map(&:freeze)
        stmt.reset!
        stmt.bind_params binds
        Result.new cols, stmt.to_a
      end

      def last_insert_row_id
        @conn.last_insert_row_id
      end
    end

    class Result < Struct.new :columns, :rows
      include Enumerable
      def empty?; rows.empty?; end
      def each; rows.each { |row| yield row }; end
    end

    class << self
      attr_accessor :connection
      def connect! database
        self.connection = Connection.new database
      end

      def exec sql, binds = []
        self.connection.execute sql, binds
      end
    end

    def self.make_schema!
      result = Database.exec "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                    ['reference_cards']
      if result.empty?
        Database.exec <<-eosql
CREATE TABLE reference_cards (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  "name" varchar(255),
  "mv_id" INTEGER,
  "reference_image_id" INTEGER,
  "mana_cost" varchar(255),
  "converted_mana_cost" INTEGER,
  "types" varchar(255),
  "text" text,
  "pt" varchar(255),
  "rarity" varchar(255),
  "rating" float,
  "created_at" datetime default current_timestamp)
        eosql
      end

      result = Database.exec "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                    ['reference_images']
      if result.empty?
        Database.exec <<-eosql
CREATE TABLE reference_images (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  "mv_id" INTEGER,
  "fingerprint_l" INTEGER,
  "fingerprint_r" INTEGER,
  "filename" varchar(255),
  "created_at" datetime default current_timestamp)
        eosql
      end
    end
  end
end
