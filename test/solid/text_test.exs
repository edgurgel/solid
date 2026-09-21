defmodule Solid.TextTest do
  use ExUnit.Case, async: true

  alias Solid.Text

  @nbsp <<0x00A0::utf8>>
  @line_sep <<0x2028::utf8>>
  @para_sep <<0x2029::utf8>>
  @ideographic <<0x3000::utf8>>
  @ogham <<0x1680::utf8>>
  @nel <<0x0085::utf8>>
  @zwsp <<0x200B::utf8>>
  @eacute <<0x00E9::utf8>>

  describe "blank_text?/1 — empty and ASCII whitespace" do
    test "empty string is blank" do
      assert Text.blank_text?("")
    end

    test "single space is blank" do
      assert Text.blank_text?(" ")
    end

    test "every ASCII whitespace byte is blank" do
      assert Text.blank_text?(" \n\r\t\f\v")
    end

    test "runs of ASCII whitespace are blank" do
      assert Text.blank_text?("   \n\t  ")
    end
  end

  describe "blank_text?/1 — ASCII non-whitespace" do
    test "a single visible char is not blank" do
      refute Text.blank_text?("x")
    end

    test "leading whitespace then a visible char is not blank" do
      refute Text.blank_text?("   x")
    end

    test "trailing visible char is not blank" do
      refute Text.blank_text?("a  ")
    end

    test "NUL is not whitespace" do
      refute Text.blank_text?(<<0>>)
    end
  end

  describe "blank_text?/1 — Unicode whitespace is NOT blank" do
    test "non-breaking space (U+00A0) is not blank" do
      refute Text.blank_text?(@nbsp)
    end

    test "line separator (U+2028) is not blank" do
      refute Text.blank_text?(@line_sep)
    end

    test "paragraph separator (U+2029) is not blank" do
      refute Text.blank_text?(@para_sep)
    end

    test "ideographic space (U+3000) is not blank" do
      refute Text.blank_text?(@ideographic)
    end

    test "ogham space mark (U+1680) is not blank" do
      refute Text.blank_text?(@ogham)
    end

    test "next line / NEL (U+0085) is not blank" do
      refute Text.blank_text?(@nel)
    end

    test "zero-width space (U+200B) is not blank" do
      refute Text.blank_text?(@zwsp)
    end

    test "ASCII whitespace around Unicode whitespace is not blank" do
      refute Text.blank_text?("  " <> @nbsp <> "  ")
    end

    test "multibyte visible text is not blank" do
      refute Text.blank_text?("caf" <> @eacute)
    end

    test "a lone continuation byte is not blank" do
      refute Text.blank_text?(<<0xC2>>)
    end
  end

  describe "blank_text?/1 — differential against Liquid's regex" do
    @liquid_blank ~r/\A\s*\z/

    @alphabet [
      " ",
      "\t",
      "\n",
      "\v",
      "a",
      <<0>>,
      <<0xFF>>,
      @nbsp,
      @ideographic,
      @zwsp,
      @eacute
    ]

    test "agrees with Liquid's rule on all sequences up to length 3" do
      corpus =
        for len <- 0..3,
            combo <- sequences(@alphabet, len),
            do: IO.iodata_to_binary(combo)

      for text <- corpus do
        assert Text.blank_text?(text) == Regex.match?(@liquid_blank, text),
               "blank_text?(#{inspect(text)}) disagreed with Liquid's /\\A\\s*\\z/"
      end
    end

    test "agrees with Liquid's rule on random byte strings" do
      for _ <- 1..5_000 do
        text = :crypto.strong_rand_bytes(:rand.uniform(6))

        assert Text.blank_text?(text) == Regex.match?(@liquid_blank, text),
               "blank_text?(#{inspect(text)}) disagreed with Liquid's /\\A\\s*\\z/"
      end
    end

    defp sequences(_alphabet, 0), do: [[]]

    defp sequences(alphabet, len) do
      for head <- alphabet, tail <- sequences(alphabet, len - 1), do: [head | tail]
    end
  end
end
