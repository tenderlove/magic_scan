require 'opencv'
require 'magic_scan'

img = OpenCV::IplImage.decode_image File.binread(ARGV[0]).bytes

strategy = MagicScan::Contours::Simple.new img
from = strategy.corners

to = [
  OpenCV::CvPoint2D32f.new(0, 0),
  OpenCV::CvPoint2D32f.new(233, 0),
  OpenCV::CvPoint2D32f.new(233, 310),
  OpenCV::CvPoint2D32f.new(0, 310),
]
transform = OpenCV::CvMat.get_perspective_transform(from, to)
new_img = img.warp_perspective transform
new_img.set_roi OpenCV::CvRect.new(0, 0, 223, 310)
window = OpenCV::GUI::Window.new 'simple'
window.show_image new_img
OpenCV::GUI.wait_key
new_img.save_image "cropped.jpg"

require 'phashion'

img1 = Phashion::Image.new 'cropped.jpg'
img2 = Phashion::Image.new 'crematetest.jpg'

p img1.duplicate? img2
