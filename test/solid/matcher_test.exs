defmodule Solid.MatcherTest do
  use ExUnit.Case, async: true

  defmodule UserProfile do
    defstruct [:full_name]

    defimpl Solid.Matcher do
      def match(user_profile, ["full_name"]), do: {:ok, user_profile.full_name}
    end
  end

  defmodule User do
    defstruct [:email]

    def load_profile(%User{} = _user) do
      # implementation omitted
      %UserProfile{full_name: "John Doe"}
    end

    defimpl Solid.Matcher do
      def match(user, ["email"]), do: {:ok, user.email}

      def match(user, ["profile" | keys]),
        do: user |> User.load_profile() |> @protocol.match(keys)
    end
  end

  defmodule BadUser do
    defstruct [:email]

    def load_profile(%BadUser{} = _user) do
      # implementation omitted
      %UserProfile{full_name: "John Doe"}
    end
  end

  test "should render protocolized struct correctly" do
    template = ~s({{ user.email }}: {{ user.profile.full_name }})

    context = %{
      "user" => %User{email: "test@example.com"}
    }

    assert "test@example.com: John Doe" ==
             template |> Solid.parse!() |> Solid.render!(context) |> to_string()
  end

  test "should not raise when struct not protocolized correctly and no strict_variables" do
    template = ~s({{ user.email }}: {{ user.profile.full_name }})

    context = %{
      "user" => %BadUser{email: "test@example.com"}
    }

    assert ": " ==
             template |> Solid.parse!() |> Solid.render!(context) |> to_string()
  end

  test "should raise when struct not protocolized correctly and strict_variables: true" do
    template = ~s({{ user.email }}: {{ user.profile.full_name }})

    context = %{
      "user" => %BadUser{email: "test@example.com"}
    }

    error =
      assert_raise(Solid.RenderError, fn ->
        template
        |> Solid.parse!()
        |> Solid.render!(context, strict_variables: true)
      end)

    assert [%Solid.MatcherNotImplementedError{struct: BadUser}, _] = Enum.reverse(error.errors)
  end
end
