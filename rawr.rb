require 'opencv'

img = OpenCV::IplImage.decode_image File.binread(ARGV[0]).bytes
gray = OpenCV.BGR2GRAY img
#blur = gray.smooth(OpenCV::CV_GAUSSIAN)
#thresh = blur.threshold(50, 255, OpenCV::CV_THRESH_BINARY)
thresh = gray.canny(100, 255)

contours = []
contour_node = thresh.find_contours(:mode => OpenCV::CV_RETR_CCOMP, :method => OpenCV::CV_CHAIN_APPROX_SIMPLE)
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
  p c.contour_area
  p c.min_area_rect2.points
  p c.min_area_rect2
  c.min_area_rect2.points
}

#ps = [card.min_area_rect2.points]

img.poly_line! ps, :thickness => 2, :color => OpenCV::CvColor::White

img.save_image("foo.jpg")
__END__
    box = contour.min_area_rect2
    p contour.contour_area
    p box.points
window = OpenCV::GUI::Window.new 'simple'
window.show_image thresh
OpenCV::GUI.wait_key
