require 'net/http/persistent'
require 'nokogiri'
require 'thread'
require 'monitor'
require 'fileutils'
require 'logger'

DEST   = ARGV[0]
LOGGER = Logger.new $stdout

class ThreadExecutor
  class Promise
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

  class Latch
    def initialize count = 1
      @count = count
      @lock  = Monitor.new
      @cv    = @lock.new_cond
    end

    def release
      @lock.synchronize do
        @count -= 1 if @count > 0
        @cv.broadcast if @count == 0
      end
    end

    def await
      @lock.synchronize { @cv.wait_while { @count > 0 } }
    end
  end

  def initialize size
    @queue = Queue.new
    @size = size
    @pool = size.times.map { |i|
      Thread.new {
        conn = Net::HTTP::Persistent.new "dn_#{i}"

        while job = @queue.pop
          job.run conn
        end
      }
    }
  end

  def execute job = Proc.new
    promise = Promise.new job
    @queue << promise
    promise
  end

  def shutdown
    @size.times { execute { |conn| conn.shutdown } }
    @size.times { @queue << nil }
    @pool.each(&:join)
  end
end

class CardQuery
  BASE = 'http://gatherer.wizards.com/Pages/Card/Details.aspx?'

  attr_reader :body, :id

  def initialize id
    @id   = id
    @url  = URI(BASE + "multiverseid=#{id}")
    @body = nil
    @dir = File.join(DEST, @id.to_s)
    @filename = File.join @dir, 'page.html'
  end

  def call conn
    if File.exist? @filename
      LOGGER.info "#{self.class}: cache hit"
    else
      @body = conn.request(@url).body
      FileUtils.mkdir_p @dir
      File.open(@filename, 'w') do |f|
        f.write @body
      end
    end
    self
  end
end

class CardImageQuery
  BASE = 'http://gatherer.wizards.com/Handlers/Image.ashx?'

  attr_reader :body, :id

  def initialize id
    @id       = id
    @url      = URI(BASE + "multiverseid=#{id}&type=card")
    @dir      = File.join(DEST, @id.to_s)
    @filename = File.join @dir, 'card.jpg'
    @body     = nil
  end

  def call conn
    if File.exist? @filename
      LOGGER.info "#{self.class}: cache hit"
    else
      @body = conn.request(@url).body
      FileUtils.mkdir_p @dir
      File.open(@filename, 'w') do |f|
        f.write @body
      end
    end
    self
  end
end

class SetQuery < Struct.new(:name, :page)
  BASE = 'http://gatherer.wizards.com/Pages/Search/Default.aspx?'
  def initialize name, page = 0
    super
    @body = nil
    @doc = nil
    @uri = URI(BASE + URI::DEFAULT_PARSER.escape("page=#{page}&set=[\"#{name}\"]"))
  end

  def call conn
    @body = conn.request(@uri).body
    @doc = Nokogiri.HTML @body
    self
  end

  def card_ids
    @doc.css('span.cardTitle > a').map { |node|
      url = @uri + URI(node['href'])
      params = Hash[url.query.split('&').map { |bit| bit.split('=') }]
      params['multiverseid'].to_i
    }
  end

  def next_page
    next_index = page + 1
    next_link = @doc.css('div.pagingControls > a').map { |link|
      @uri + URI(link['href'])
    }.find { |url|
      params = Hash[url.query.split('&').map { |bit| bit.split('=') }]
      params['page'].to_i == next_index
    }
    next_link && SetQuery.new(name, next_index)
  end
end

web_executor = ThreadExecutor.new 10

set_names = web_executor.execute do |conn|
  uri = URI 'http://gatherer.wizards.com/Pages/Default.aspx'
  response = conn.request uri
  doc = Nokogiri.HTML response.body
  nodes = doc.css '#ctl00_ctl00_MainContent_Content_SearchControls_setAddText > option'
  nodes.reject { |node| node['value'].empty? }.map { |node| node['value'] }
end

set = web_executor.execute SetQuery.new set_names.value.first

assets = set.value.card_ids.flat_map { |card_id|
  [
    CardQuery.new(card_id),
    CardImageQuery.new(card_id),
  ].map { |job| web_executor.execute job }
}
assets.each { |a| a.value }

#sets.value.map { |set_name|
#  web_executor.execute SetQuery.new set_name
#}

web_executor.shutdown
