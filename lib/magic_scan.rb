require 'opencv'
require 'av_capture'

module MagicScan
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
        approx = max.approx_poly(:method => :dp, :recursive => true, :accuracy => 0.02 * peri)

        x = approx.convex_hull2.to_a.reverse
        debug_points x, @img
        x.map { |point|
          OpenCV::CvPoint2D32f.new(point)
        }
      end

      private
      def debug_points points, img
        colors = [
          OpenCV::CvColor::White,
          OpenCV::CvColor::Black,
          OpenCV::CvColor::Blue,
          OpenCV::CvColor::Green,
        ]
        points.each_with_index do |point,i|
          img.circle!(point, 10, :color => colors[i], :thickness => 5)
        end
        show img
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
