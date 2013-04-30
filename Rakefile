require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('uniquify', '0.1.0') do |p|
  p.description    = "Implements contentable module."
  p.url            = "http://github.com/balinaanna/content"
  p.author         = "111minutes.com"
  p.email          = "ann.balina@gmail.com"
  p.ignore_pattern = ["tmp/*", "script/*"]
  p.development_dependencies = []
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }