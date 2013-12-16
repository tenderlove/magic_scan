require 'magic_scan/latch'

module MagicScan
  class Promise
    attr_reader :job

    def initialize job
      @job   = job
      @value = nil
      @latch = Latch.new
    end

    def run(*args)
      @value = @job.call(*args)
      @latch.release
    end

    def value
      @latch.await
      @value
    end
  end
end
