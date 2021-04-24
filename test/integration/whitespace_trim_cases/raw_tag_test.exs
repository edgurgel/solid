import WhitespaceTrimHelper

# TODO: Handle {%- endraw %} which isn't valid and errors the parser.
test_permutations "raw tag" do
  """
  ########################

  {{'hallo' }}

  {% raw %}

  {{ 5 | plus: 6 }}

  {% endraw %} equals 11.

  {% raw %} {{ {% {%  {% endraw %} equals 11.
  {% raw %}{% increment counter %}{{ counter }}{% endraw %}

  ########################
  """
end
