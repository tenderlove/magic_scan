require 'opencv'
require 'av_capture'
require 'magic_scan/frames'
require 'magic_scan'
require 'sqlite3'
require 'active_record'
require 'image'
require 'user_image'
require 'card'
require 'reference_image'
require 'config/application'
require 'logger'

def build card_id, jpg, hash
  UserImage.transaction do
    ui = UserImage.build_with_hash_and_bytes hash, jpg
    ui.save!
    Card.find(card_id).images << ui
  end
end

ActiveRecord::Base.logger = Logger.new 'log/development.log'

dev = AVCapture.devices.find(&:video?) # AVCaptureDevice

db = SQLite3::Database.new 'db/development.sqlite3'
db.enable_load_extension true
db.load_extension Phashion.so_file

limit  = 3
WIDTH  = 233
HEIGHT = 310

stmt = db.prepare <<-eosql
SELECT cards.name,
       hamming_distance(images.fingerprint_l,
                        images.fingerprint_r,
                        ?, ?) as hd,
       cards.id,
       images.filename
FROM cards, images, cards_images
WHERE cards.id = cards_images.card_id
AND   images.id = cards_images.image_id
ORDER BY hd
LIMIT #{limit}
eosql

img = OpenCV::IplImage.new((limit + 1) * WIDTH, HEIGHT)
win = OpenCV::GUI::Window.new 'omg'
win.resize img.size.width, img.size.height

mode = :scanning

MagicScan::Photo.run dev do |cut|
  jpg   = MagicScan::Photo.to_jpg cut
  hash  = MagicScan::Photo.hash_from_buffer jpg
  left  = hash >> 32
  right = hash & 0xFFFFFFFF

  img.set_roi OpenCV::CvRect.new(0, 0, WIDTH, HEIGHT)
  img.copy_in cut

  rows = stmt.execute(left, right).to_a

  rows.each_with_index do |row, i|
    str  = File.binread row.last
    read = OpenCV::IplImage.decode_image str.bytes

    ul = (i + 1) * WIDTH
    img.set_roi OpenCV::CvRect.new(ul, 0, WIDTH, HEIGHT)
    img.copy_in read
  end

  img.reset_roi
  win.show_image img

  wait = nil
  if mode == :scanning
    wait = 10
  end

  case val = OpenCV::GUI.wait_key(wait)
  when 113 then exit # q
  when 115 then
    if mode == :slow
      mode = :scanning
    else
      mode = :slow
    end
  when 117 # u
    ui = UserImage.find(UserImage.maximum(:id))
    p "deleted #{ui.cards.map(&:name)}"
    ui.destroy
  when 104 # h
    print "Enter card id: "
    card = Card.find gets.to_i
    build card.id, jpg, hash
    puts "Saved #{card.name}"
  when 49, 50, 51 # 1, 2, or 2
    row = rows[val - 49]
    build row[2], jpg, hash
    puts "Saved #{row[0]}"
    mode = :scanning
  when 120
    puts "#" * 90
    rows.each do |row|
      p row
    end
    puts "#" * 90
  when nil
  else
    p val
  end
end
