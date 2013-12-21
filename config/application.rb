require 'active_record'
require 'phashion'

module MagicScan
  db_root = File.expand_path File.join(File.dirname(__FILE__), '..', 'db')

  DB_ENV = {
    'production'  => "sqlite3://#{db_root}/production.sqlite3",
    'test'        => "sqlite3://#{db_root}/test.sqlite3",
    'development' => "sqlite3://#{db_root}/development.sqlite3"
  }
  env = ENV['RAILS_ENV'] || 'development'
  ActiveRecord::Base.establish_connection DB_ENV[env]
end

class ActiveRecord::Base
  class << self
    alias :old :sqlite3_connection
    def sqlite3_connection config
      conn = old config
      if conn.connection.respond_to? :enable_load_extension
        conn.connection.enable_load_extension true
        conn.connection.load_extension Phashion.so_file
      else
        conn.connection.define_function('hamming_distance') { |l1,r1,l2,r2|
          left  = (l1 << 32) + r1
          right = (l2 << 32) + r2
          Phashion.hamming_distance left, right
        }
      end
      conn
    end
  end
end

class ActiveRecord::ConnectionAdapters::SQLite3Adapter
  attr_reader :connection
end
