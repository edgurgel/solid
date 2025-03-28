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

  test "should render protocolized struct correctly" do
    template = ~s({{ user.email }}: {{ user.profile.full_name }})

    context = %{
      "user" => %User{email: "test@example.com"}
    }

    assert "test@example.com: John Doe" ==
             template |> Solid.parse!() |> Solid.render!(context) |> to_string()
  end
end
