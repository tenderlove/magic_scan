require 'magic_scan'
require 'tempfile'
require 'webrick'
require 'json'

image_queue = Queue.new

Thread.abort_on_exception = true

server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => ARGV[1]

Thread.new {
  server.mount_proc '/stream' do |req, res|
    rd, wr = IO.pipe
    res['Content-Type'] = 'text/event-stream'
    res.body = rd
    res.chunked = true
    Thread.new {
      while job = image_queue.pop
        image, ref_img, refcard = job
        data = {
          "scanned_image" => [image].pack('m'),
          "ref_image"     => [File.read(ref_img.filename)].pack('m'),
          "title"         => refcard.name
        }
        begin
          wr.write "data: #{JSON.dump(data)}\n\n"
        rescue Errno::EPIPE
          wr.close
          break
        end
      end
    }
  end

  server.start
}

MagicScan::Database.connect! ARGV[0]

MagicScan::Photo.run do |conn|
  loop do
    img = loop {
      image = conn.take_photo
      data = MagicScan::Photo.find_and_crop image, 233, 310
      break(data) if data
    }

    tf = Tempfile.open 'card.jpg'
    tf.write img
    tf.flush
    hash = Phashion.image_hash_for tf.path
    distance, ref = MagicScan::ReferenceImage.find_with_matching_hash hash
    tf.close
    tf.unlink
    if ref
      card = MagicScan::ReferenceCard.find_by_mv_id ref.mv_id
      image_queue << [img, ref, card]
      p [card.name, ref.filename, distance]
    else
      print "."
    end
  end
end

trap('INT') { server.shutdown }
