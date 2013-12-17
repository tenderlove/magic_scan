require 'test_helper'

class ImageTest < ActiveSupport::TestCase
  FIXTURES = File.join Rails.root, 'test', 'fixtures'

  fixtures :cards

  def test_find_by_hash
    card = cards :cremate

    file = File.join(FIXTURES, 'cremate.jpg')
    hash = Phashion.image_hash_for file
    img  = ReferenceImage.create!(:fingerprint  => hash,
                                  :filename => file)
    img.save!

    img2 = ReferenceImage.find_by_hash hash
    assert_equal img, img2
  end

  def test_fingerprint
    card = cards :cremate
    file = File.join FIXTURES, 'cremate.jpg'

    hash = Phashion.image_hash_for file
    img  = ReferenceImage.create!(:fingerprint  => hash,
                                  :filename => file)
    assert_equal hash, img.fingerprint
  end
end
