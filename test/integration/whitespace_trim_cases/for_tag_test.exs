import WhitespaceTrimHelper

test_permutations "for tag", ~s({ "var" : [1, 2, 3]}) do
  """
  ########################

  {% for value in var %}

    {% if value > 2 %}
      Got: {{ value }}
    {% endif %}

  {% endfor %}

  ########################
  """
end
