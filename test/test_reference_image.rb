require 'minitest/autorun'
require 'magic_scan'

class ReferenceImageTest < MiniTest::Test
  def setup
    MagicScan::Database.connection = SQLite3::Database.new(':memory:')
    MagicScan::Database.make_schema! MagicScan::Database.connection
  end

  def test_save!
    img = MagicScan::ReferenceImage.create 1, 2, 'foo'
    assert_nil img.id
    img.save!
    refute_nil img.id
    img2 = MagicScan::ReferenceImage.find_by_id img.id

    assert_equal img.id, img2.id
    assert_equal img.fingerprint, img2.fingerprint
    assert_equal img.filename, img2.filename
  end
end
