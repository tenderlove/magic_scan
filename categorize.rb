require 'nokogiri'
require 'sqlite3'
require 'uri'

base_dir = ARGV[0]

class Card < Struct.new :name, :mana_cost, :converted_mana_cost, :types, :text, :pt, :rarity, :rating
  class Parser
    attr_reader :doc, :id

    def initialize doc, id
      @doc = doc
      @id  = id
    end

    def card
      Card.new name, mana_cost, converted_mana_cost, types, text, pt, rarity, rating
    end

    def name
      node = doc.at_css "##{id}_nameRow > div.value"
      node.text.strip
    end

    def mana_cost
      nodes = doc.css "##{id}_manaRow > div.value > img"
      if nodes.any?
        nodes.map { |node|
          extract_mana_color node
        }.join
      else
        nil
      end
    end

    def converted_mana_cost
      node = doc.at_css "##{id}_cmcRow > div.value"
      if node
        node.text.strip.to_i
      else
        nil
      end
    end

    def types
      node = doc.at_css "##{id}_typeRow > div.value"
      node.text.strip
    end

    def text
      nodes = doc.css "##{id}_textRow > div.value > div"
      nodes.each { |n|
        n.css('img').each { |img|
          img.add_next_sibling extract_mana_color img
        }
        n.css('img').each(&:unlink)
      }
      nodes.map { |n| n.text }.join "\n"
    end

    def pt
      node = doc.at_css "##{id}_ptRow > div.value"
      if node
        node.text.strip
      else
        nil
      end
    end

    def rarity
      node = doc.at_css "##{id}_rarityRow > div.value"
      node.text.strip
    end

    def rating
      node = doc.at_css "##{id}_currentRating_textRating"
      node.text.strip.to_f
    end

    private
    def extract_mana_color node
      URI(node['src']).query.split('&').map { |part|
        part.split '='
      }.find { |l,r| l == 'name' }[1]
    end
  end

  def self.parse doc
    doc.xpath("//div[contains(@id,'nameRow')]").map { |node|
      Parser.new(doc, node['id'].match(/^(.*)_nameRow$/)[1]).card
    }
  end
end

Dir.chdir base_dir do
  if ARGV[1]
    dir = ARGV[1]
    Dir.chdir dir do
      doc = File.open('page.html') do |f|
        Nokogiri.HTML f
      end
      p :CARD_ID => dir.to_i
      Card.parse(doc).each do |card|
        [
          :name,
          :mana_cost,
          :converted_mana_cost,
          :types,
          :text,
          :pt,
          :rarity,
          :rating
        ].each do |attr|
          p attr => card.send(attr)
        end
      end
    end
  else
    Dir.entries('.').each do |dir|
      next if dir == '.' || dir == '..'
      next unless File.directory? dir

      Dir.chdir dir do
        doc = File.open('page.html') do |f|
          Nokogiri.HTML f
        end
        p :CARD_ID => dir
        Card.parse(doc).each do |card|
          [
            :name,
            :mana_cost,
            :converted_mana_cost,
            :types,
            :text,
            :pt,
            :rarity,
            :rating
          ].each do |attr|
            p attr => card.send(attr)
          end
        end
      end
    end
  end
end
__END__
doc = File.open(File.join(base_dir, '373661', 'page.html')) do |f|
  Nokogiri.HTML f
end

card = Card.new doc
p card.name
p card.mana_cost
p card.converted_mana_cost
p card.types
p card.text
p card.pt
p card.rarity
p card.rating
