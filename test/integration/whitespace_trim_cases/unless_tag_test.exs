import WhitespaceTrimHelper

test_permutations "unless tag evaluated to unless body" do
  """
  ########################

  {{ ' I am a object' }}
  {% unless false %}

    I'm a unless-body

  {% elsif false %}

    I'm a elsif-body

  {% else %}

    I'm a else-body

  {% endunless %}

  ########################
  """
end

test_permutations "unless tag evaluated to elsif body" do
  """
  ########################

  {{ ' I am a object' }}
  {% unless true %}

    I'm a unless-body

  {% elsif true %}

    I'm a elsif-body

  {% else %}

    I'm a else-body

  {% endunless %}

  ########################
  """
end

test_permutations "unless tag evaluated to else body" do
  """
  ########################

  {{ ' I am a object' }}
  {% unless true %}

    I'm a unless-body

  {% elsif false %}

    I'm a elsif-body

  {% else %}

    I'm a else-body

  {% endunless %}

  ########################
  """
end

test_permutations "unless tag evaluated to nothing" do
  """
  ########################

  {{ ' I am a object' }}
  {% unless true %}

    I'm a unless-body

  {% elsif false %}

    I'm a elsif-body

  {% endunless %}

  ########################
  """
end
