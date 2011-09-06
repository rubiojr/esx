require 'rubygems'
require 'rake'
require 'lib/esx.rb'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.version = ESX::VERSION
  gem.name = "esx"
  gem.homepage = "http://github.com/rubiojr/esx"
  gem.license = "MIT"
  gem.summary = %Q{Simple RbVmomi wrapper library to manage VMWare ESX hosts}
  gem.description = %Q{Manage VMWare ESX hosts with ease}
  gem.email = "rubiojr@frameos.org"
  gem.authors = ["Sergio Rubio"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  gem.add_runtime_dependency 'alchemist'
  gem.add_runtime_dependency 'rbvmomi'
  gem.add_runtime_dependency 'terminal-table'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :build

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = ESX::VERSION
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "esx #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
