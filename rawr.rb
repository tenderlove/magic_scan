require 'opencv'

img = OpenCV::IplImage.decode_image File.binread(ARGV[0]).bytes
gray = OpenCV.BGR2GRAY img
#blur = gray.smooth(OpenCV::CV_GAUSSIAN)
#thresh = blur.threshold(50, 255, OpenCV::CV_THRESH_BINARY)
thresh = gray.canny(100, 255)

contours = []
contour_node = thresh.find_contours(:mode => OpenCV::CV_RETR_TREE, :method => OpenCV::CV_CHAIN_APPROX_SIMPLE)
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
  p from.map(&:to_s)
  to = [
    OpenCV::CvPoint2D32f.new(0, 0),
    OpenCV::CvPoint2D32f.new(233, 0),
    OpenCV::CvPoint2D32f.new(233, 310),
    OpenCV::CvPoint2D32f.new(0, 310),
  ]
  transform = OpenCV::CvMat.get_perspective_transform(from.rotate, to)
  new_img = img.warp_perspective transform
  new_img.set_roi OpenCV::CvRect.new(0, 0, 223, 310)
window = OpenCV::GUI::Window.new 'simple'
window.show_image new_img
OpenCV::GUI.wait_key
  exit!
  rect = c.min_area_rect2
  r = rect.points
  h = OpenCV::CvMat.new(3, 3, :cv32f1)
  h[0] = OpenCV::CvScalar.new(0, 0)
  h[1] = OpenCV::CvScalar.new(233, 0)
  h[2] = OpenCV::CvScalar.new(233, 310)
  h[3] = OpenCV::CvScalar.new(0, 310)
  p r
  p rect
  i = OpenCV::CvMat.new(3, 3, :cv32f1)

  approx.min_area_rect2.points.each_with_index do |point, index|
    i[index] = OpenCV::CvScalar.new(point.x, point.y)
  end

  transform = h.perspective_transform i
}

exit!
#ps.each do |points|
#  mat = OpenCV::CvMat.new(3, 3, :cv32f1)
#  mat[0] = OpenCV::CvScalar.new(0, 0)
#  mat[1] = OpenCV::CvScalar.new(233, 0)
#  mat[2] = OpenCV::CvScalar.new(233, 310)
#  mat[3] = OpenCV::CvScalar.new(0, 310)
#  transform = points.perspective_transform mat
#  warped = img.warp_perspective transform
#  warped.set_roi(0, 0, 223, 210)
#
#        #cv.GetPerspectiveTransform(corners, target, mat)
#        #warped = cv.CloneImage(color_capture)
#        #cv.WarpPerspective(color_capture, warped, mat)
#        #cv.SetImageROI(warped, (0,0,223,310) )
#end

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
