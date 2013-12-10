require 'minitest/autorun'
require 'magic_scan'

class ReferenceImageTest < MiniTest::Test
  FIXTURES = File.join File.dirname(__FILE__), 'fixtures'

  def setup
    MagicScan::Database.connect! ':memory:'
    MagicScan::Database.make_schema!
  end

  def test_save!
    img = MagicScan::ReferenceImage.create 1, 2, 'foo'
    assert_nil img.id
    img.save!
    refute_nil img.id
    img2 = MagicScan::ReferenceImage.find_by_id img.id

    assert_same_image img, img2
  end

  def test_find_by_hash
    file = File.join(FIXTURES, 'cremate.jpg')
    hash = Phashion.image_hash_for file
    img  = MagicScan::ReferenceImage.create 1, hash, file
    img.save!

    img2 = MagicScan::ReferenceImage.find_by_hash hash
    assert_same_image img, img2
  end

  def test_find_by_similar_hash
    file = File.join(FIXTURES, 'cremate.jpg')
    file2 = File.join(FIXTURES, 'cremate2.jpg')
    hash = Phashion.image_hash_for file
    img  = MagicScan::ReferenceImage.create 1, hash, file
    img.save!

    hash = Phashion.image_hash_for file2
    img2 = MagicScan::ReferenceImage.find_with_matching_hash hash
    assert_same_image img, img2
  end

  def assert_same_image img1, img2
    assert_equal img1.id, img2.id
    assert_equal img1.fingerprint, img2.fingerprint
    assert_equal img1.filename, img2.filename
  end
end
