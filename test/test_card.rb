require 'minitest/autorun'
require 'magic_scan'

module MagicScan
  class CardTest < MiniTest::Test
    FIXTURES = File.join File.dirname(__FILE__), 'fixtures'

    def setup
      MagicScan::Database.connect! ':memory:'
      MagicScan::Database.make_schema!
    end

    def test_attributes
      card = ReferenceCard.new card_info
      card_info.each_pair do |k,v|
        assert_equal v, card.send(k)
      end
    end

    def test_save
      card = ReferenceCard.new card_info
      card.save!
      refute_nil card.id
      card2 = ReferenceCard.find_by_id card.id
      card_info.each_pair do |k,v|
        assert_equal v, card2.send(k)
      end
    end

    def card_info
      {
        :name                => "Wei Scout",
        :mana_cost           => "1B",
        :converted_mana_cost => 2,
        :types               => "Creature  — Human Soldier Scout",
        :text                => "Horsemanship (This creature can't be blocked except by creatures with horsemanship.)",
        :pt                  => "1 / 1",
        :rarity              => "Common",
        :rating              => 2.481,
        :mv_id               => 10517}
    end
  end
end
