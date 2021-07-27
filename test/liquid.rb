require 'liquid'
require 'json'

module SubstituteFilter
  def substitute(input, params = {})
    input.gsub(/%\{(\w+)\}/) { |_match| params[Regexp.last_match(1)] }
  end
end

context = Liquid::Context.new(JSON.parse(ARGV[1]))
context.add_filters(SubstituteFilter)

puts Liquid::Template.parse(ARGV[0]).render(context)
