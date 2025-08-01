require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"
require "bump/tasks"

namespace :test do
  Rake::TestTask.new(:unit) do |t|
    t.test_files = FileList["test/unit/**/*_test.rb"]
    t.verbose = true
  end

  Rake::TestTask.new(:acceptance) do |t|
    t.test_files = FileList["test/acceptance_test.rb"]
    t.verbose = true
  end

  desc 'run all tests'
  task all: [:unit, :acceptance]
end

task test: 'test:all'

task default: 'test:all'
