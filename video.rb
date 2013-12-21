require 'opencv'
require 'av_capture'
require 'magic_scan/frames'
require 'magic_scan'

dev = AVCapture.devices.find(&:video?) # AVCaptureDevice

win = OpenCV::GUI::Window.new 'omg'
win.resize 233, 310

MagicScan::Photo.run dev do |cut|
  win.show_image cut
  if 113 == OpenCV::GUI.wait_key(10)
    break
  end
end
