require 'net/http/persistent'
require 'thread'
require 'magic_scan/promise'

module MagicScan
  class ThreadExecutor
    def initialize size
      @queue = Queue.new
      @size = size
      @pool = size.times.map { |i|
        Thread.new {
          while job = @queue.pop
            job.run
          end
        }
      }
    end

    def execute job = Proc.new
      if job
        promise = Promise.new job
      else
        promise = nil
      end
      @queue << promise
      promise
    end

    def shutdown
      @size.times { @queue << nil }
      @pool.each(&:join)
    end
  end
end
