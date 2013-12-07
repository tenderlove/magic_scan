require 'net/http/persistent'
require 'nokogiri'
require 'thread'
require 'monitor'
Thread.abort_on_exception = true

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

uri = URI 'http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=100'
web_executor = ThreadExecutor.new 1

#promise = executor.execute do |conn|
#  response = conn.request uri
#  doc = Nokogiri.HTML response.body
#  node = doc.at_css('#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_cardImage')
#  conn.request(uri + URI(node['src'])).body
#end

class SetQuery < Struct.new(:name, :page)
  BASE = 'http://gatherer.wizards.com/Pages/Search/Default.aspx?'
  def initialize name, page = 0
    super
    @body = nil
    @uri = URI(BASE + URI::DEFAULT_PARSER.escape("page=#{page}&set=[\"#{name}\"]"))
  end

  def call conn
    @body = conn.request(@uri).body
    @doc = Nokogiri.HTML @body
    self
  end

  def card_urls
    @doc.css('span.cardTitle > a').map { |node|
      [node.text, @uri + URI(node['href'])]
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

sets = web_executor.execute do |conn|
  uri = URI 'http://gatherer.wizards.com/Pages/Default.aspx'
  response = conn.request uri
  doc = Nokogiri.HTML response.body
  nodes = doc.css '#ctl00_ctl00_MainContent_Content_SearchControls_setAddText > option'
  nodes.reject { |node| node['value'].empty? }.map { |node| node['value'] }
end

promise = web_executor.execute SetQuery.new sets.value.first
promise = web_executor.execute promise.value.next_page
p promise.value.next_page
#sets.value.map { |set_name|
#  web_executor.execute SetQuery.new set_name
#}

web_executor.shutdown
