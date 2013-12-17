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

      infos.map { |info|
        exe.execute {
          info.fingerprint = Phashion.image_hash_for info.source_file
        }

        exe.execute {
          hex         = Digest::MD5.hexdigest File.binread info.source_file
          info.digest = hex
          FileUtils.mkdir_p info.dest_dir
          FileUtils.cp info.source_file, info.dest_file
        }

        exe.execute {
          info.cards = MagicScan::Parser.parse_file info.source_html, info.mv_id
        }
      }

      exe.shutdown

      info.each { |info|
        img = ReferenceImage.create!(:fingerprint => info.fingerprint,
                                     :filename    => info.dest_file)
        info.cards.each do |card_info|
          card = Card.new card_info
          card.image = img
          card.save!
        end
      }
    end
  end
end
