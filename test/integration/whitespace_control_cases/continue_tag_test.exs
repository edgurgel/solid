import WhitespaceTrimHelper

# test_permutations "continue tag outside for body" do
# """
# ########################

# this should print

# {% continue %}

# this should not print

# ########################
# """
# end

test_permutations "continue tag inside for body" do
  """
  ########################

  {% for i in (1..5) %}

    {% if i == 4 %}

      x

      {% continue %}

    {% else %}

      {{ i }}

    {% endif %}

  {% endfor %}

  ########################
  """
end
