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
  end

  test "should render protocolized struct correctly" do
    template = ~s({{ user.email }}: {{ user.profile.full_name }})

    context = %{
      "user" => %User{email: "test@example.com"}
    }

    assert "test@example.com: John Doe" ==
             template |> Solid.parse!() |> Solid.render!(context) |> to_string()
  end

  describe "struct without Solid.Matcher implementation" do
    setup do
      %{
        template: Solid.parse!(~s({{ user.email }}: {{ user.profile.full_name }})),
        context: %{"user" => %BadUser{email: "test@example.com"}}
      }
    end

    test "renders nil without errors when strict_variables is off", %{
      template: template,
      context: context
    } do
      assert {:ok, result, []} = Solid.render(template, context)
      assert ": " == to_string(result)
    end

    test "reports MatcherNotImplementedError when strict_variables is on", %{
      template: template,
      context: context
    } do
      assert {:error, errors, result} = Solid.render(template, context, strict_variables: true)
      assert ": " == to_string(result)

      assert [
               %Solid.MatcherNotImplementedError{
                 struct: BadUser,
                 variable: ["user", "email"],
                 original_name: "user.email"
               },
               %Solid.MatcherNotImplementedError{
                 struct: BadUser,
                 variable: ["user", "profile", "full_name"],
                 original_name: "user.profile.full_name"
               }
             ] = errors
    end

    test "render! raises when strict_variables is on", %{template: template, context: context} do
      error =
        assert_raise Solid.RenderError, fn ->
          Solid.render!(template, context, strict_variables: true)
        end

      assert [%Solid.MatcherNotImplementedError{} = first | _] = error.errors

      assert Exception.message(first) ==
               "1: Protocol Solid.Matcher not implemented for Solid.MatcherTest.BadUser (user.email)"
    end
  end
end
