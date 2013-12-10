require 'opencv'
require 'av_capture'
require 'sqlite3'
require 'phashion'

module MagicScan
  class ReferenceImage
    attr_reader :mvid, :filename, :id

    def self.create mvid, hash, filename
      right = hash & 0xFFFFFFFF
      left  = (hash >> 32) & 0xFFFFFFFF
      new mvid, left, right, filename
    end

    def self.find_by_id id
      stmt = Database.stmt_cache "SELECT * FROM reference_images WHERE id = ?"
      row = stmt.execute id
      instance = allocate
      instance.init_with_hash Hash[stmt.columns.zip row.first]
      instance
    end

    def initialize mvid, fingerprint_l, fingerprint_r, filename
      @mvid          = mvid
      @fingerprint_l = fingerprint_l
      @fingerprint_r = fingerprint_r
      @filename      = filename
      @id            = nil
    end

    def init_with_hash hash
      hash.each_pair { |k,v|
        instance_variable_set :"@#{k}", v
      }
    end

    def fingerprint
      (@fingerprint_l << 32) + @fingerprint_r
    end

    def save!
      stmt = Database.stmt_cache "INSERT INTO reference_images
                  (mv_id, fingerprint_l, fingerprint_r, filename) VALUES (?, ?, ?, ?)"
      stmt.execute @mvid, @fingerprint_l, @fingerprint_r, @filename
      @id = Database.connection.last_insert_row_id
    end
  end

  module Database
    @stmt_cache = {}

    class << self
      attr_accessor :connection

      def stmt_cache sql
        @stmt_cache[sql] ||= connection.prepare sql
      end
    end

    def self.make_schema! db
      stmt = db.prepare "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
      result = stmt.execute 'reference_cards'
      if result.to_a.empty?
        db.execute <<-eosql
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

      result = stmt.execute 'reference_images'
      if result.to_a.empty?
        db.execute <<-eosql
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

  module Contours
    class Simple
      def initialize img
        @img = img
      end

      def corners
        processed = processed_image @img

        contours = []
        contour_node = processed.find_contours(:mode   => OpenCV::CV_RETR_TREE,
                                            :method => OpenCV::CV_CHAIN_APPROX_SIMPLE)
        while contour_node
          unless contour_node.hole?
            contours << contour_node
          end
          contour_node = contour_node.h_next
        end

        contours = contours.find_all { |c| c.length > 10 }

        max = contours.max_by { |c|
          c.contour_area
        }

        peri = max.arc_length
        approx = max.approx_poly(:method => :dp,
                                 :recursive => true,
                                 :accuracy => 0.02 * peri)

        x = approx.convex_hull2.to_a.reverse
        clockwise x.map { |point|
          OpenCV::CvPoint2D32f.new(point)
        }, @img.size
      end

      private
      # probably a better way, but care =~ 0
      def clockwise points, size
        [
          [0, 0],                    # upper left
          [size.width, 0],           # upper right
          [size.width, size.height], # bottom right
          [0, size.height],          # bottom left
        ].map { |x,y|
          points.min_by { |point|
            Math.sqrt(((point.x - x) ** 2) + ((point.y - y) ** 2))
          }
        }
      end

      def debug_points points, img
        colors = [
          OpenCV::CvColor::White,
          OpenCV::CvColor::Black,
          OpenCV::CvColor::Blue,
          OpenCV::CvColor::Green,
        ]
        points.each_with_index do |point,i|
          img.circle!(point, 10, :color => colors.fetch(i, OpenCV::CvColor::White), :thickness => 5)
        end
        show img
        points
      end
      def processed_image img
        gray = OpenCV.BGR2GRAY img
        #blur = gray.smooth(OpenCV::CV_GAUSSIAN)
        #thresh = blur.threshold(50, 255, OpenCV::CV_THRESH_BINARY)
        gray.canny 100, 100
      end

      def show img
        window = OpenCV::GUI::Window.new 'simple'
        window.show_image img
        OpenCV::GUI.wait_key
        window.destroy
      end
    end
  end

  def self.find_reference frames
    loop do
      last_image = frames.next_image
      window = OpenCV::GUI::Window.new 'simple'
      window.show_image last_image

      begin
        case OpenCV::GUI.wait_key
        when 13
          break last_image
        else
        end
      ensure
        window.destroy
      end
    end
  end

  def self.delta last, current
    size     = last.size
    n_pixels = size.height * size.width
    tmp      = last - current
    tmp.mul(tmp).sum[0] / n_pixels
  end

  def self.find_card base, frame, thresh = 100
    diff = frame.abs_diff base
    edges = diff.canny thresh, thresh
    contours = edges.find_contours
    contours.each do |contour|
      p contours.length
    end
  end

  class Frames
    include Enumerable

    def initialize dev
      @dev = dev
      @session = AVCapture::Session.new # AVCaptureSession
      @output  = AVCapture::StillImageOutput.new # AVCaptureOutput subclass
      @session.add_input @dev.as_input
      @session.add_output @output
      @session.start_running!
      @connection = @output.video_connection
    end

    def next_image
      image = @output.capture_on @connection
      OpenCV::IplImage.decode_image image.data.bytes
    end

    def each
      loop do
        yield next_image
      end
    end
  end

  class GSFilter
    include Enumerable

    def initialize enum
      @enum = enum
    end

    def next_image
      OpenCV.RGB2GRAY @enum.next_image
    end

    def each; loop { yield next_image }; end
  end
end
