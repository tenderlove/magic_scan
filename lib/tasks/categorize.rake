desc "Categorize the cards"
task :categorize => :environment do
  require 'magic_scan/categorizer'

  Thread.abort_on_exception = true
  cat = MagicScan::Categorizer.new
  cat.process 'tmp/cards'
end
