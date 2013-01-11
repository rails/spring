require "bundler/gem_tasks"
require "rake/testtask"

namespace :test do

  TEST_APPLICATION_PATH = 'test/apps/rails-3-2'

  desc 'initialize the testing environment'
  task :setup do
    sh "cd #{TEST_APPLICATION_PATH} && rake db:migrate db:test:prepare"
  end

  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.test_files = FileList["test/unit/*_test.rb"]
    t.verbose = true
  end

  Rake::TestTask.new(:acceptance) do |t|
    t.libs << "test"
    t.test_files = FileList["test/acceptance/*_test.rb"]
    t.verbose = true
  end

  desc 'run all tests'
  task all: [:unit, :acceptance]
end

task default: ['test:setup', 'test:all']
