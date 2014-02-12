require 'rake'
require 'rspec/core/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)

YARD::Rake::YardocTask.new(:yardoc)

desc "Start Sinatra Server one on port 4567"
task :sinatra_one do
  require 'test/sinatra/server_one'
  ServerOne.run!(:port => 4567)
end

desc "Start Sinatra Server two port 4568"
task :sinatra_two do
  require 'test/sinatra/server_two'
  ServerTwo.run!(:port => 4568)
end

desc "Start Hello World! Sinatra Server port 4569"
task :sinatra_hello_world do
  require 'test/sinatra/hello_world_server'
  HelloWorldServer.run!(:port => 4569)
end
