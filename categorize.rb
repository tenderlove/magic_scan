require 'nokogiri'
require 'sqlite3'
require 'uri'

base_dir = ARGV[0]

doc = File.open(File.join(base_dir, '373661', 'page.html')) do |f|
  Nokogiri.HTML f
end

class Card
  attr_reader :doc

  def initialize doc
    @doc = doc
  end

  def name
    node = doc.at_css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_nameRow > div.value"
    node.text.strip
  end

  def mana_cost
    nodes = doc.css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_manaRow > div.value > img"
    nodes.map { |node|
      extract_mana_color node
    }.join
  end

  def converted_mana_cost
    node = doc.at_css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_cmcRow > div.value"
    node.text.strip
  end

  def types
    node = doc.at_css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_typeRow > div.value"
    node.text.strip
  end

  def text
    nodes = doc.css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_textRow > div.value > div"
    nodes.each { |n|
      n.css('img').each { |img|
        img.add_next_sibling extract_mana_color img
      }
      n.css('img').each(&:unlink)
    }
    nodes.map { |n| n.text }.join "\n"
  end

  def pt
    node = doc.at_css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow > div.value"
    node.text.strip
  end

  def pt
    node = doc.at_css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ptRow > div.value"
    node.text.strip
  end

  def rarity
    node = doc.at_css "#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_rarityRow > div.value"
    node.text.strip
  end

  private
  def extract_mana_color node
    URI(node['src']).query.split('&').map { |part|
      part.split '='
    }.find { |l,r| l == 'name' }[1]
  end
end

card = Card.new doc
p card.name
p card.mana_cost
p card.converted_mana_cost
p card.types
p card.text
p card.pt
p card.rarity
