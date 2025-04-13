require 'liquid'
require 'json'
require 'time'

ENV['TZ'] = 'UTC'

module SubstituteFilter
  def substitute(input, params = {})
    input.gsub(/%\{(\w+)\}/) { |_match| params[Regexp.last_match(1)] }
  end
end

if ARGV[2]
  Liquid::Environment.default.file_system = Liquid::LocalFileSystem.new(ARGV[2])
end

context = Liquid::Context.new(JSON.parse(ARGV[1]))
context.add_filters(SubstituteFilter)


puts Liquid::Template.parse(ARGV[0], error_mode: :strict, line_numbers: true).render(context)
