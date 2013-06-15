def connected?
  ActiveRecord::Base.connection
  true
rescue
  false
end

task :with_env => :environment do
  puts connected?
end

task :with_env_recursive => :with_env

task :without_env do
  puts connected?
end
