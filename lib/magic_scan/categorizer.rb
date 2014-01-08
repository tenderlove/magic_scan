require 'nokogiri'
require 'thread'
require 'card'
require 'reference_image'
require 'magic_scan/thread_executor'
require 'magic_scan/parser'
require 'phashion'
require 'digest/md5'
require 'fileutils'

module MagicScan
  class Categorizer
    class Info < Struct.new :dir, :mv_id, :fingerprint, :digest, :filename, :cards
      def source_file
        File.join dir, mv_id.to_s, 'card.jpg'
      end

      def source_html
        File.join dir, mv_id.to_s, 'page.html'
      end

      def dest_dir
        File.join 'app', 'assets', 'images', digest[0,2]
      end

      def dest_file
        File.join dest_dir, "#{digest}.jpg"
      end
    end

    def process dir
      infos = Dir.entries(dir).map { |mv_id|
        entry = File.join(dir, mv_id)
        next unless File.directory? entry
        next if '..' == mv_id || '.' == mv_id

        Info.new dir, mv_id.to_i
      }.compact

      exe = MagicScan::ThreadExecutor.new 8

      latches = infos.each_with_index.map { |info, i|
        latch = MagicScan::Latch.new 3
        exe.execute {
          info.fingerprint = Phashion.image_hash_for info.source_file
          latch.release
        }

        exe.execute {
          hex         = Digest::MD5.hexdigest File.binread info.source_file
          info.digest = hex
          FileUtils.mkdir_p info.dest_dir
          FileUtils.cp info.source_file, info.dest_file
          latch.release
        }

        exe.execute {
          info.cards = MagicScan::Parser.parse_file info.source_html, info.mv_id
          latch.release
        }

        [info, latch]
      }

      latches.each { |info, latch|
        latch.await
        img = ReferenceImage.find_by_filename(info.dest_file)
        unless img
          img = ReferenceImage.create!(:fingerprint => info.fingerprint,
                                       :filename    => info.dest_file)
        end
        img_cards = img.cards.to_a
        info.cards.each do |card_info|
          card = make_card card_info
          unless img_cards.include? card
            img.cards << card
          end
        end
      }
      exe.shutdown
    end

    def make_card info
      card = Card.find_by_mv_id info[:mv_id]
      if card
        card.update_attributes info
      else
        card = Card.new info
        card.save!
      end
      card
    end
  end
end
