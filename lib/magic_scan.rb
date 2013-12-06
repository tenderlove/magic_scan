require 'opencv'
require 'av_capture'

module MagicScan
  module Contours
    class Simple
      def initialize img
        @img = img
      end

      def corners
        contours = []
        contour_node = processed_image(@img).find_contours(:mode   => OpenCV::CV_RETR_TREE,
                                            :method => OpenCV::CV_CHAIN_APPROX_SIMPLE)
        while contour_node
          unless contour_node.hole?
            contours << contour_node
          end
          contour_node = contour_node.h_next
        end

        ps = contours.find_all { |c|
          c.contour_area > 10000
        }.sort_by { |c|
          c.contour_area
        }.map { |c|
          peri = c.arc_length
          approx = c.approx_poly(:method => :dp, :recursive => true, :accuracy => 0.02 * peri)

          from = c.min_area_rect2.points
          return from.rotate
        }
      end

      private
      def processed_image img
        gray = OpenCV.BGR2GRAY img
        #blur = gray.smooth(OpenCV::CV_GAUSSIAN)
        #thresh = blur.threshold(50, 255, OpenCV::CV_THRESH_BINARY)
        gray.canny 100, 255
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
