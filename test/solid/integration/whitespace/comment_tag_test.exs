import WhitespaceTrimHelper

test_permutations "comment tag" do
  """
  ########################

  {{ ' I am a object' }}
  {% comment %}

  This is a comment

  {% endcomment %}

  ########################
  """
end
