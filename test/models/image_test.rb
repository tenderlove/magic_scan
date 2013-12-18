require 'test_helper'

class ImageTest < ActiveSupport::TestCase
  FIXTURES = File.join Rails.root, 'test', 'fixtures'

  fixtures :cards

  def test_find_by_hash
    file = File.join(FIXTURES, 'cremate.jpg')
    hash = Phashion.image_hash_for file
    img  = ReferenceImage.create!(:fingerprint  => hash,
                                  :filename => file)
    img.save!

    img2 = ReferenceImage.find_by_hash hash
    assert_equal img, img2
  end

  def test_fingerprint
    file = File.join FIXTURES, 'cremate.jpg'

    hash = Phashion.image_hash_for file
    img  = ReferenceImage.create!(:fingerprint  => hash,
                                  :filename => file)
    assert_equal hash, img.fingerprint
  end

  def test_find_similar
    img = create 'cremate.jpg'
    file = File.join FIXTURES, 'cremate2.jpg'
    hash = Phashion.image_hash_for file

    similar = ReferenceImage.find_similar hash

    assert_equal [img], similar
    assert similar.first.distance
  end

  def test_similar_to_file
    img = create 'cremate.jpg'
    file = File.join FIXTURES, 'cremate2.jpg'

    similar = ReferenceImage.find_similar_to_file file

    assert_equal [img], similar
    assert similar.first.distance
  end

  def create filename
    file = File.join FIXTURES, 'cremate.jpg'

    hash = Phashion.image_hash_for file
    ReferenceImage.create!(:fingerprint => hash, :filename => file)
  end
end
