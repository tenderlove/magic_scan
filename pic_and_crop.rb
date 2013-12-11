require 'magic_scan'
require 'tempfile'
require 'webrick'
require 'json'

image_queue = Queue.new

Thread.abort_on_exception = true

Thread.new {
  server = WEBrick::HTTPServer.new :Port => 8000,
  :DocumentRoot => ARGV[1]

  trap('INT') { server.shutdown }

  server.mount_proc '/stream' do |req, res|
    rd, wr = IO.pipe
    res['Content-Type'] = 'text/event-stream'
    res.body = rd
    res.chunked = true
    Thread.new {
      while image = image_queue.pop
        wr.write "data: #{JSON.dump("image" => [image].pack('m'))}\n\n"
      end
    }
  end

  server.start
}

MagicScan::Database.connect! ARGV[0]

MagicScan::Photo.run do |conn|
  loop do
    found = loop do
      img = loop {
        image = conn.take_photo
        data = MagicScan::Photo.find_and_crop image, 233, 310
        if data
          puts "FOUND DATA"
          break(data)
        else
          puts "NO DATA :("
        end
      }

      tf = Tempfile.open 'card.jpg'
      tf.write img
      tf.flush
      hash = Phashion.image_hash_for tf.path
      ref = MagicScan::ReferenceImage.find_with_matching_hash hash
      tf.close
      tf.unlink
      if ref
        puts "FOUND REFERENCE"
        image_queue << img
        break(ref)
      else
        puts "NO REFERENCE :("
      end
    end
    card = MagicScan::ReferenceCard.find_by_mv_id found.mv_id
    puts card.name => found.filename
  end
end
