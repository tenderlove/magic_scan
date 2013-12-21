require 'opencv'
require 'av_capture'
require 'phashion'

module MagicScan
  module Photo
    class Capture < Struct.new :output
      def take_photo
        connection = output.video_connection
        output.capture_on(connection).data
      end
    end

    def self.show img
      window = OpenCV::GUI::Window.new 'simple'
      window.show_image img
      OpenCV::GUI.wait_key
      window.destroy
    end

    def self.run
      session = AVCapture::Session.new # AVCaptureSession
      dev     = AVCapture.devices.find(&:video?) # AVCaptureDevice

      $stderr.puts "Starting session on #{dev.name}"
      output  = AVCapture::StillImageOutput.new # AVCaptureOutput subclass
      session.add_input dev.as_input
      session.add_output output
      session.start_running!
      yield Capture.new output
      session.stop_running!
    end

    def self.find_and_crop img, width, height
      strategy = MagicScan::Contours::Simple.new img
      from = strategy.corners

      return nil if from.empty?

      to = [
        OpenCV::CvPoint2D32f.new(0, 0),
        OpenCV::CvPoint2D32f.new(width, 0),
        OpenCV::CvPoint2D32f.new(width, height),
        OpenCV::CvPoint2D32f.new(0, height),
      ]
      transform = OpenCV::CvMat.get_perspective_transform(from, to)
      new_img = img.warp_perspective transform
      new_img.set_roi OpenCV::CvRect.new(0, 0, width, height)
      yield new_img
      new_img.encode_image(".jpg").pack 'C*'
    end
  end

  module Contours
    class Simple
      def initialize img
        @img = img
      end

      def corners processed, img
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

        max = contours.max_by { |c| c.contour_area }

        return [] unless max
        return [] unless max.contour_area > 100_00

        peri = max.arc_length
        approx = max.approx_poly(:method => :dp,
                                 :recursive => true,
                                 :accuracy => 0.02 * peri)

        x = approx.convex_hull2.to_a
        clockwise_points = clockwise x.map { |point|
          OpenCV::CvPoint2D32f.new(point)
        }, img.size

        top_length = distance clockwise_points[0], clockwise_points[1]
        side_length = distance clockwise_points[0], clockwise_points[3]

        if top_length > side_length
          []
        else
          clockwise_points
        end
      end

      def processed_image img
        gray = OpenCV.BGR2GRAY img
        #blur = gray.smooth(OpenCV::CV_GAUSSIAN)
        #thresh = blur.threshold(50, 255, OpenCV::CV_THRESH_BINARY)
        gray.canny 100, 100
      end

      private
      def distance a, b
        Math.sqrt(((a.x - b.x) ** 2) + ((a.y - b.y) ** 2))
      end

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
