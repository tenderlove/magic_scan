$: << '.'
$: << 'lib'
$: << 'app/models'

require 'active_record'

task :environment do
  require 'rake/application'
  require 'config/application'
end

task :test do
  $: << 'test'
  Dir['test/**/*.rb'].each do |file|
    require file
  end
end

task :console => :environment do
  require 'irb'
  ARGV.clear # otherwise all script parameters get passed to IRB
  IRB.start
end

task :create_migration, :name do |t, args|
  t = Time.now.utc
  s = t.strftime("%Y%m%d%H%M%S")
  n = args[:name]
  File.open("db/migrate/#{s}_#{n.downcase.gsub(/\s/, '_')}.rb", 'w') do |f|
    f.write <<-eofile
class #{n.split(/\s/).map(&:capitalize).join} < ActiveRecord::Migration
  def change
  end
end
    eofile
  end
end

Rake.application.rake_require 'active_record/railties/databases'

# So that schema dumping doesn't blow up. :-/
# https://github.com/rails/rails/blob/92f9ff8cc325d72d74cbf839ac9ac0acd474a768/activerecord/lib/active_record/railties/databases.rake#L242
ActiveRecord::Tasks::DatabaseTasks.db_dir = 'db'

Rake.application.rake_require 'tasks/categorize'
Rake.application.rake_require 'tasks/download'
