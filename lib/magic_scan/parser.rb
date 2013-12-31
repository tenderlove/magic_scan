require 'nokogiri'

module MagicScan
  class Parser
    def self.parse doc, mv_id
      doc.xpath("//div[contains(@id,'nameRow')]").map { |node|
        Parser.new(doc, node['id'].match(/^(.*)_nameRow$/)[1]).card mv_id
      }
    end

    def self.parse_file file, mv_id
      doc = Nokogiri.HTML File.read file
      parse doc, mv_id
    end

    attr_reader :doc, :id

    def initialize doc, id
      @doc = doc
      @id  = id
    end

    def card mv_id
      {
        :name                => name,
        :mana_cost           => mana_cost,
        :converted_mana_cost => converted_mana_cost,
        :types               => types,
        :text                => text,
        :pt                  => pt,
        :rarity              => rarity,
        :rating              => rating,
        :mv_id               => mv_id,
        :expansion           => expansion,
      }
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

    def expansion
      node = doc.at_css "##{id}_currentSetSymbol"
      node.text.strip
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
end
