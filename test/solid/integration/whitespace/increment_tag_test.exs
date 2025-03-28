import WhitespaceTrimHelper

test_permutations "increment tag", ~s({ "counter" : 0 }) do
  """
  ########################

  {% increment counter %}

  {% increment counter %}

  ########################
  """
end
