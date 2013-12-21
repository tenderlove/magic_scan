desc "Download cards from Gatherer"
task :download => :environment do
  require 'magic_scan/downloader'

  Thread.abort_on_exception = true

  downloader = MagicScan::Downloader.new Rails.logger
  downloader.fetch_all_sets.each(&:value)
  downloader.shutdown
end
