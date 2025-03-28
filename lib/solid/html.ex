defmodule Solid.HTML do
  # Vendored in from Plug.HTML
  #
  #
  # Copyright (c) 2013 Plataformatec.

  # Licensed under the Apache License, Version 2.0 (the "License");
  # you may not use this file except in compliance with the License.
  # You may obtain a copy of the License at

  #     http://www.apache.org/licenses/LICENSE-2.0

  # Unless required by applicable law or agreed to in writing, software
  # distributed under the License is distributed on an "AS IS" BASIS,
  # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  # See the License for the specific language governing permissions and
  # limitations under the License.
  #

  @moduledoc """
  Conveniences for generating HTML.
  """

  @doc ~S"""
  Escapes the given HTML to string.

  iex> Plug.HTML.html_escape("foo")
  "foo"

  iex> Plug.HTML.html_escape("<foo>")
  "&lt;foo&gt;"

  iex> Plug.HTML.html_escape("quotes: \" & \'")
  "quotes: &quot; &amp; &#39;"
  """
  @spec html_escape(String.t()) :: String.t()
  def html_escape(data) when is_binary(data) do
    IO.iodata_to_binary(to_iodata(data, 0, data, []))
  end

  @doc ~S"""
  Escapes the given HTML to iodata.

  iex> Plug.HTML.html_escape_to_iodata("foo")
  "foo"

  iex> Plug.HTML.html_escape_to_iodata("<foo>")
  [[[] | "&lt;"], "foo" | "&gt;"]

  iex> Plug.HTML.html_escape_to_iodata("quotes: \" & \'")
  [[[[], "quotes: " | "&quot;"], " " | "&amp;"], " " | "&#39;"]

  """
  @spec html_escape_to_iodata(String.t()) :: iodata
  def html_escape_to_iodata(data) when is_binary(data) do
    to_iodata(data, 0, data, [])
  end

  escapes = [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc) do
      to_iodata(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc) do
    to_iodata(rest, skip, original, acc, 1)
  end

  defp to_iodata(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      to_iodata(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc, len) do
    to_iodata(rest, skip, original, acc, len + 1)
  end

  defp to_iodata(<<>>, 0, original, _acc, _len) do
    original
  end

  defp to_iodata(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end

  # Addition
  for {match, insert} <- escapes do
    def replacements(<<unquote(match)>>), do: unquote(insert)
  end
end
