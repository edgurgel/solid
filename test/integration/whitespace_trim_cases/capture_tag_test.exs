import WhitespaceTrimHelper

test_permutations "capture tag" do
  """
  ########################

  {% capture string_with_newlines_and_whitespace %}

  Hello

  there

  {% endcapture %}

  {{ string_with_newlines_and_whitespace }}

  ########################
  """
end
