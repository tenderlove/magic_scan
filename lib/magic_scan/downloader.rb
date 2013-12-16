require 'nokogiri'
require 'fileutils'
require 'logger'
require 'magic_scan/thread_executor'
require 'magic_scan/http_connection_pool'

module MagicScan
  class Downloader
    attr_reader :dest
    attr_reader :logger

    class SetQuery < Struct.new(:http_pool, :name, :page)
      BASE = 'http://gatherer.wizards.com/Pages/Search/Default.aspx?'

      def initialize http_pool, name, page = 0
        super
        @body = nil
        @doc = nil
        @uri = URI(BASE + URI::DEFAULT_PARSER.escape("page=#{page}&set=[\"#{name}\"]"))
      end

      def call
        @body = http_pool.with_connection { |conn|
          conn.request(@uri).body
        }
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
        next_link && SetQuery.new(http_pool, name, next_index)
      end
    end

    class CardDownload
      def initialize id, dest, http, logger
        @id     = id
        @dir    = File.join dest, @id.to_s
        @logger = logger
        @http   = http
        @body   = nil
      end
    end

    class CardQuery < CardDownload
      BASE = 'http://gatherer.wizards.com/Pages/Card/Details.aspx?'

      attr_reader :body, :id

      def initialize id, dest, http, logger
        super
        @url  = URI(BASE + "multiverseid=#{id}")
        @filename = File.join @dir, 'page.html'
      end

      def call
        if File.exist? @filename
          @logger.info "#{self.class}: cache hit"
        else
          @body = @http.with_connection { |conn| conn.request(@url).body }
          FileUtils.mkdir_p @dir
          File.open(@filename, 'wb') { |f| f.write @body }
        end
        self
      end
    end

    class CardImageQuery < CardDownload
      BASE = 'http://gatherer.wizards.com/Handlers/Image.ashx?'

      attr_reader :body, :id

      def initialize id, dest, http, logger
        super
        @url      = URI(BASE + "multiverseid=#{id}&type=card")
        @filename = File.join @dir, 'card.jpg'
      end

      def call
        if File.exist? @filename
          @logger.info "#{self.class}: cache hit"
        else
          @body = @http.with_connection { |conn| conn.request(@url).body }

          FileUtils.mkdir_p @dir
          File.open(@filename, 'wb') { |f| f.write @body }
        end
        self
      end
    end

    def initialize logger = Logger.new($stderr)
      @dest      = File.join Rails.root, 'tmp', 'cards'
      @executor  = MagicScan::ThreadExecutor.new 10
      @logger    = Logger.new $stderr
      @http_pool = MagicScan::HttpConnectionPool.new 10
    end

    def set_names
      @executor.execute do
        @http_pool.with_connection do |conn|
          uri = URI 'http://gatherer.wizards.com/Pages/Default.aspx'
          response = conn.request uri
          doc = Nokogiri.HTML response.body
          nodes = doc.css '#ctl00_ctl00_MainContent_Content_SearchControls_setAddText > option'
          nodes.reject { |node| node['value'].empty? }.map { |node| node['value'] }
        end
      end
    end

    def fetch_all_sets
      set_names.value.flat_map { |name| fetch_set name }
    end

    def fetch_set set_name
      current_set = @executor.execute SetQuery.new @http_pool, set_name

      assets = []

      loop do
        job = current_set.job
        @logger.info "downloading set #{job.name} #{job.page}"

        assets.concat current_set.value.card_ids.flat_map { |mv_id|
          [ fetch_card(mv_id), fetch_card_image(mv_id) ]
          yield mv_id if block_given?
        }
        next_page = current_set.value.next_page

        break unless next_page

        current_set = @executor.execute next_page
      end

      assets
    end

    def fetch_card card_id
      query = CardQuery.new card_id, @dest, @http_pool, @logger
      @executor.execute query
    end

    def fetch_card_image card_id
      query = CardImageQuery.new card_id, @dest, @http_pool, @logger
      @executor.execute query
    end

    def shutdown
      @executor.shutdown
      @http_pool.shutdown
    end
  end
end
