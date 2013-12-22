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

Rake.application.rake_require 'active_record/railties/databases'

# So that schema dumping doesn't blow up. :-/
# https://github.com/rails/rails/blob/92f9ff8cc325d72d74cbf839ac9ac0acd474a768/activerecord/lib/active_record/railties/databases.rake#L242
ActiveRecord::Tasks::DatabaseTasks.db_dir = 'db'

Rake.application.rake_require 'tasks/categorize'
Rake.application.rake_require 'tasks/download'
