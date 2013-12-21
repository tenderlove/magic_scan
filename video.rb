require 'opencv'
require 'av_capture'
require 'magic_scan/frames'
require 'magic_scan'

dev = AVCapture.devices.find(&:video?) # AVCaptureDevice

win = OpenCV::GUI::Window.new 'omg'
win.resize 233, 310

class Processor
  def process img
    gray = OpenCV.BGR2GRAY img
    #blur = gray.smooth(OpenCV::CV_GAUSSIAN)
    #thresh = blur.threshold(50, 255, OpenCV::CV_THRESH_BINARY)
    yield gray.canny 100, 100
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

frames = MagicScan::Frames.new dev
fc = Cropper.new 233, 310
processor = Processor.new
corners = MagicScan::Contours::Simple.new

frames.each do |img|
  processor.process img do |canny|
    corners.process(canny, img) do |points|
      fc.process(points, img) do |cut|
        win.show_image cut
      end
    end
  end
  if 113 == OpenCV::GUI.wait_key(10)
    break
  end
end
