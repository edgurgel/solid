import WhitespaceTrimHelper

test_permutations "if tag evaluated to if body" do
  """
  ########################

  {{ ' I am a object' }}
  {% if true %}

    I'm a if-body

  {% elsif false %}

    I'm a elsif-body

  {% else %}

    I'm a else-body

  {% endif %}

  ########################
  """
end

test_permutations "if tag evaluated to elsif body" do
  """
  ########################

  {{ ' I am a object' }}
  {% if false %}

    I'm a if-body

  {% elsif true %}

    I'm a elsif-body

  {% else %}

    I'm a else-body

  {% endif %}

  ########################
  """
end

test_permutations "if tag evaluated to else body" do
  """
  ########################

  {{ ' I am a object' }}
  {% if false %}

    I'm a if-body

  {% elsif false %}

    I'm a elsif-body

  {% else %}

    I'm a else-body

  {% endif %}

  ########################
  """
end

test_permutations "if tag evaluated to nothing" do
  """
  ########################

  {{ ' I am a object' }}
  {% if false %}

    I'm a if-body

  {% elsif false %}

    I'm a elsif-body

  {% endif %}

  ########################
  """
end
