require 'opencv'
require 'av_capture'
require 'phashion'

module MagicScan
  module Photo
    def self.show img
      window = OpenCV::GUI::Window.new 'simple'
      window.show_image img
      OpenCV::GUI.wait_key
      window.destroy
    end

    def self.run dev
      frames    = MagicScan::Frames.new dev
      fc        = MagicScan::Photo::Cropper.new 233, 310
      processor = MagicScan::Photo::Processor.new
      corners   = MagicScan::Photo::Simple.new

      frames.each do |img|
        processor.process img do |canny|
          corners.process(canny, img) do |points|
            fc.process(points, img) do |cut|
              yield cut
            end
          end
        end
      end
    end

    def self.to_jpg img
      img.encode_image(".jpg").pack 'C*'
    end

    class Processor
      def initialize thresh = 100
        @thresh = thresh
      end

      def process img
        gray = OpenCV.BGR2GRAY img
        #blur = gray.smooth(OpenCV::CV_GAUSSIAN)
        #thresh = blur.threshold(50, 255, OpenCV::CV_THRESH_BINARY)
        yield gray.canny @thresh, @thresh
      end
    end

    class Cropper
      attr_reader :width, :height, :to

      def initialize width, height
        @to = [
          OpenCV::CvPoint2D32f.new(0, 0),
          OpenCV::CvPoint2D32f.new(width, 0),
          OpenCV::CvPoint2D32f.new(width, height),
          OpenCV::CvPoint2D32f.new(0, height),
        ]
        @width = width
        @height = height
      end

      def process from, img
        transform = OpenCV::CvMat.get_perspective_transform(from, to)
        new_img = img.warp_perspective transform
        new_img.set_roi OpenCV::CvRect.new(0, 0, width, height)
        yield new_img
      end
    end

    class Simple
      def process processed, img
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

        return unless max
        return unless max.contour_area > 100_00

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

        unless top_length > side_length
          yield clockwise_points
        end
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

  def self.delta last, current
    size     = last.size
    n_pixels = size.height * size.width
    tmp      = last - current
    tmp.mul(tmp).sum[0] / n_pixels
  end
end
