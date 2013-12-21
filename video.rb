require 'opencv'
require 'av_capture'
require 'magic_scan/frames'
require 'magic_scan'

dev = AVCapture.devices.find(&:video?) # AVCaptureDevice

win = OpenCV::GUI::Window.new 'omg'
win.resize 233, 310

class FindAndCrop
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

  def process img
    strategy = MagicScan::Contours::Simple.new img
    from = strategy.corners

    unless from.empty?
      transform = OpenCV::CvMat.get_perspective_transform(from, to)
      new_img = img.warp_perspective transform
      new_img.set_roi OpenCV::CvRect.new(0, 0, width, height)
      yield new_img
    end
  end
end

frames = MagicScan::Frames.new dev
fc = FindAndCrop.new 233, 310

frames.each do |img|
  fc.process(img) do |cut|
    win.show_image cut
  end
  if 113 == OpenCV::GUI.wait_key(10)
    break
  end
end
