require 'opencv'
require 'av_capture'

module MagicScan
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
