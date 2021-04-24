import WhitespaceTrimHelper

test_permutations "assign tag" do
  """
  ########################

  {% assign food = 'pizza' %}

  {{ food }}

  ########################
  """
end
