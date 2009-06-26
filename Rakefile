# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  load 'tasks/setup.rb'
end

ensure_in_path 'lib'
require 'bigfloat/version'

task :default => 'spec:run'


PROJ.name = 'bigfloat'
PROJ.description = "Arbitray-Precision Floating-Point"
PROJ.authors = 'Javier Goizueta'
PROJ.email = 'javier@goizueta.info'
PROJ.version = BigFloat::VERSION::STRING
PROJ.rubyforge.name = 'ruby-decimal'
PROJ.url = "http://#{PROJ.rubyforge.name}.rubyforge.org"
PROJ.rdoc.opts = [
  "--main", "README.txt",
  '--title', 'Ruby Decimal Documentation',
  "--opname", "index.html",
  "--line-numbers",
  "--inline-source"
  ]
#PROJ.test.file = 'test/all_tests.rb'

# EOF
