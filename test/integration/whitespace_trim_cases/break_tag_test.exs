import WhitespaceTrimHelper

test_permutations "break tag outside for body" do
  """
  ########################

  this should print

  {% break %}

  this should not print

  ########################
  """
end

test_permutations "break tag inside for body" do
  """
  ########################

  {% for i in (1..5) %}

    {% if i == 4 %}

      x

      {% break %}

    {% else %}

      {{ i }}

    {% endif %}

  {% endfor %}

  ########################
  """
end
