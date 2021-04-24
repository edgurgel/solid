import WhitespaceTrimHelper

test_permutations "case tag evaluated to when body", ~s({ "shipping_method" : { "title" : "Local Pick-Up" } }) do
  """
  ########################

  {% case shipping_method.title %}

  {% when 'Local Pick-Up' %}

    Your order will be ready for pick-up tomorrow.

  {% else %}

     Thank you for your order!

  {% endcase %}

  ########################
  """
end

test_permutations "case tag evaluated to else body", ~s({ "shipping_method" : { "title" : "Something else" } }) do
  """
  ########################

  {% case shipping_method.title %}

  {% when 'Local Pick-Up' %}

    Your order will be ready for pick-up tomorrow.

  {% else %}

     Thank you for your order!

  {% endcase %}

  ########################
  """
end

test_permutations "case tag evaluated to nothing", ~s({ "shipping_method" : { "title" : "Something else" } }) do
  """
  ########################

  {% case shipping_method.title %}

  {% when 'Local Pick-Up' %}

    Your order will be ready for pick-up tomorrow.

  {% endcase %}

  ########################
  """
end
