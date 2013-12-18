# Be sure to restart your server when you modify this file.

# You can add backtrace silencers for libraries that you're using but don't wish to see in your backtraces.
# Rails.backtrace_cleaner.add_silencer { |line| line =~ /my_noisy_library/ }

# You can also remove all the silencers if you're trying to debug a problem that might stem from framework code.
# Rails.backtrace_cleaner.remove_silencers!
class ActiveRecord::Base
  class << self
    alias :old :sqlite3_connection
    def sqlite3_connection config
      conn = old config
      conn.connection.define_function('hamming_distance') { |l1,r1,l2,r2|
        left  = (l1 << 32) + r1
        right = (l2 << 32) + r2
        Phashion.hamming_distance left, right
      }
      conn
    end
  end
end

class ActiveRecord::ConnectionAdapters::SQLite3Adapter
  attr_reader :connection
end
