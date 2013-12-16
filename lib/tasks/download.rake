require 'magic_scan/downloader'

task :download => :environment do
  Thread.abort_on_exception = true

  downloader = MagicScan::Downloader.new Rails.logger
  downloader.fetch_all_sets.each(&:value)
  downloader.shutdown
end
