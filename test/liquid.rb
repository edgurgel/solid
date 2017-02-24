require 'liquid'
require 'json'
hash = JSON.parse(ARGV[1])
puts Liquid::Template.parse(ARGV[0]).render(hash)
