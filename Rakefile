require "rake/testtask"

namespace :test do
  desc "run unit tests"
  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.test_files = FileList['test/**/*_test.rb']
    t.verbose = true
  end

  desc "run integration test"
  Rake::TestTask.new(:integration) do |t|
    t.libs << "test"
    t.test_files = FileList['test/**/*_integrationtest.rb']
    t.verbose = true
  end

  desc "run all tests"
  task :all => [:unit, :integration] do
  end
end

desc "Run all unittests (takes ~60s). To run integration test (takes ~30s), use 'rake test:integration' or 'rake test:all'."
task default: ['test:unit']
