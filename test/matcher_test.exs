defmodule MatcherTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  describe "custom matchers" do
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

      context = %{"user" => %User{email: "test@example.com"}}

      assert "test@example.com: John Doe" == render(template, context)
    end
  end

  describe "built-in matchers" do
    test "for maps" do
      template = ~s({{ beep.boop }})

      context = %{"beep" => %{"boop" => "beep boop!"}}

      assert "beep boop!" == render(template, context)
    end

    test "for strings" do
      template =
        ~s(How long is {{piece_of_string}}? {{piece_of_string.size}}.)

      context = %{"piece_of_string" => "a piece of string"}

      assert "How long is a piece of string? 17." == render(template, context)
    end

    test "for lists" do
      template = ~s(This eagle is just {{items.size}} {{items[1]}}s in a trenchcoat.)

      context = %{
        "items" => ~w(This parrot has ceased to be.)
      }

      assert "This eagle is just 6 parrots in a trenchcoat." == render(template, context)
    end

    test "for atoms" do
      Enum.each(
        [
          {~s({{molecule.atom.particle}}),
           %{"molecule" => %{"atom" => %{"particle" => :neutron}}}, "neutron"},
           {~s({{beep.boop}}), %{"beep" => nil}, ""}
        ],
        fn {template, context, expected} ->
          assert expected == render(template, context)
        end
      )
    end
  end
end
