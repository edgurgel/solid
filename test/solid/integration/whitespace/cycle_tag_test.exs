import WhitespaceTrimHelper

test_permutations "cycle tag" do
  """
  ########################

  {% cycle "one", "two", "three" %}

  {% cycle "one", "two", "three" %}

  {% cycle "one", "two", "three" %}

  ########################
  """
end
