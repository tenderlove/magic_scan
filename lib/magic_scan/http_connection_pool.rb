require 'thread'

module MagicScan
  class HttpConnectionPool
    def initialize size
      @queue = Queue.new
      @size  = size
      size.times { |i|
        @queue << Net::HTTP::Persistent.new("dn_#{i}")
      }
    end

    def checkout
      @queue.pop
    end

    def checkin conn
      @queue.push conn
    end

    def with_connection
      conn = checkout
      yield conn
    ensure
      checkin conn
    end

    def shutdown
      @size.times { checkout.shutdown }
    end
  end
end
