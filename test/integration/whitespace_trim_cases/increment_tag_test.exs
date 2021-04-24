import WhitespaceTrimHelper

test_permutations "increment tag", ~s({ "counter" : 1 }) do
  """
  ########################

  {% increment counter %}

  {% increment counter %}

  ########################
  """
end
