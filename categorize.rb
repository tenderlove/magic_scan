require 'nokogiri'
require 'sqlite3'
require 'uri'
require 'magic_scan'
require 'find'

#if $0 == __FILE__
require 'optparse'

options = {
  :db_file => File.expand_path('database.sqlite3')
}

OptionParser.new { |opts|
  opts.on("--database [FILE]", "SQLite3 Database File") do |file|
    options[:db_file] = file
  end

  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit!
  end
}.parse!

base_dir = ARGV[0]

Thread.abort_on_exception = true
MagicScan::Database.connect! options[:db_file]
MagicScan::Database.make_schema!

hash_queue  = Queue.new
info_queue  = Queue.new
write_queue = Queue.new

write_pool = Thread.new {
  while job = write_queue.pop
    job.save!
  end
}

Find.find(base_dir).each do |file|
  next if File.directory? file

  mv_id = file.split(File::SEPARATOR)[-2].to_i

  case file
  when /jpg$/
    hash_queue << [mv_id, file]
  when /html$/
    info_queue << [mv_id, file]
  else
    p "oh no!" => file
  end
end

hash_pool = 4.times.map {
  Thread.new {
    while job = hash_queue.pop
      mv_id, file = *job
      hash  = Phashion.image_hash_for file
      img = MagicScan::ReferenceImage.create mv_id, hash, file
      write_queue << img
    end
  }
}
hash_pool.size.times { hash_queue << nil }
hash_pool.each(&:join)

info_pool = 4.times.map {
  Thread.new {
    while job = info_queue.pop
      mv_id, file = *job
      MagicScan::Parser.parse_file(file, mv_id).each do |card|
        write_queue << card
      end
    end
  }
}
info_pool.size.times { info_queue << nil }
info_pool.each(&:join)
write_queue << nil
write_pool.join
