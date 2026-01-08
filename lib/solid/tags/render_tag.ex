defmodule Solid.Tags.RenderTag do
  alias Solid.{Argument, Context, Parser}
  alias Solid.Parser.Loc

  @type t :: %__MODULE__{
          loc: Loc.t(),
          template: binary,
          arguments:
            {:with, {source :: Argument.t(), destination :: binary}}
            | {:for, {source :: Argument.t(), destination :: binary}}
            | %{binary => Argument.t()}
        }

  @enforce_keys [:loc, :template, :arguments]
  defstruct [:loc, :template, :arguments]

  @behaviour Solid.Tag

  @impl true
  def parse("render", loc, context) do
    with {:ok, tokens, context} <- Solid.Lexer.tokenize_tag_end(context),
         {:ok, template, tokens} <- template(tokens),
         {:ok, arguments} <- parse_arguments(tokens, template) do
      {:ok, %__MODULE__{loc: loc, template: template, arguments: arguments}, context}
    end
  end

  defp parse_arguments(tokens, template) do
    case tokens do
      [{:identifier, _, "with"} | rest] -> parse_with_or_for_arguments(rest, :with, template)
      [{:identifier, _, "for"} | rest] -> parse_with_or_for_arguments(rest, :for, template)
      # Parse optional comma
      [{:comma, _} | rest] -> parse_list_of_arguments(rest)
      # No initial comma
      [{:identifier, _, _} | _] -> parse_list_of_arguments(tokens)
      [{:end, _}] -> {:ok, %{}}
      _ -> {:error, "Expected arguments, 'with' or 'for'", Parser.meta_head(tokens)}
    end
  end

  defp parse_with_or_for_arguments(tokens, type, template) do
    with {:ok, first, tokens} <- Argument.parse(tokens) do
      case tokens do
        [{:identifier, _, "as"}, {:identifier, _, key}, {:end, _}] ->
          {:ok, {type, {first, key}}}

        [{:end, _}] ->
          {:ok, {type, {first, template}}}

        _ ->
          {:error, "Unexpected token", Parser.meta_head(tokens)}
      end
    end
  end

  defp parse_list_of_arguments(tokens, acc \\ %{}) do
    case tokens do
      [{:identifier, _, key}, {:colon, _} | rest] ->
        with {:ok, value, rest} <- Argument.parse(rest) do
          acc = Map.put(acc, key, value)

          case rest do
            [{:comma, _} | rest] ->
              parse_list_of_arguments(rest, acc)

            [{:end, _}] ->
              {:ok, acc}

            _ ->
              {:error, "Expected arguments, 'with' or 'for'", Solid.Parser.meta_head(rest)}
          end
        end

      _ ->
        {:error, "Expected arguments, 'with' or 'for'", Solid.Parser.meta_head(tokens)}
    end
  end

  defp template(tokens) do
    case tokens do
      [{:string, _meta, value, _quotes} | rest] -> {:ok, value, rest}
      _ -> {:error, "Expected template name as a quoted string", tokens}
    end
  end

  defimpl Solid.Renderable do
    def render(tag, context, options) do
      cache_module = Keyword.get(options, :cache_module, Solid.Caching.NoCache)

      {file_system, instance} = options[:file_system] || {Solid.BlankFileSystem, nil}

      case file_system.read_template_file(tag.template, instance) do
        {:ok, template_str} ->
          do_render(tag, template_str, cache_module, context, options)

        {:error, exception} ->
          # Enhance exception with the tag location
          exception = %{exception | loc: tag.loc}

          {"This liquid context does not allow includes.",
           Solid.Context.put_errors(context, [exception])}
      end
    end

    defp do_render(tag, template_str, cache_module, context, options) do
      cache_key = cache_key(template_str)

      result =
        case cache_module.get(cache_key) do
          {:ok, cached_template} ->
            {:ok, cached_template}

          {:error, :not_found} ->
            parse_and_cache_partial(template_str, options, cache_key, cache_module)
        end

      case result do
        {:ok, template} ->
          {inner_contexts, context} = build_contexts(tag.arguments, context, options)

          {rendered_text, context} =
            Enum.reduce(inner_contexts, {[], context}, fn inner_context, {result, context} ->
              case Solid.render(template, inner_context, options) do
                {:ok, rendered_text, errors} ->
                  {[rendered_text | result],
                   Solid.Context.put_errors(context, Enum.reverse(errors))}

                {:error, errors, rendered_text} ->
                  {[rendered_text | result],
                   Solid.Context.put_errors(context, Enum.reverse(errors))}
              end
            end)

          {Enum.reverse(rendered_text), context}

        {:error, exception} ->
          {[], Solid.Context.put_errors(context, [exception])}
      end
    end

    defp build_contexts({:with, {source, destination}}, outter_context, options) do
      {:ok, value, outter_context} = Argument.get(source, outter_context, [], options)
      inner_context = %Context{vars: %{destination => value}}

      {[inner_context], outter_context}
    end

    defp build_contexts({:for, {source, destination}}, outter_context, options) do
      {:ok, value, outter_context} = Argument.get(source, outter_context, [], options)

      if is_list(value) do
        length = Enum.count(value)

        inner_contexts =
          value
          |> Enum.with_index(0)
          |> Enum.map(fn {v, index} ->
            forloop = build_forloop_map(index, length)
            %Context{vars: %{destination => v}, iteration_vars: %{"forloop" => forloop}}
          end)

        {inner_contexts, outter_context}
      else
        inner_context = %Context{vars: %{destination => value}}
        {[inner_context], outter_context}
      end
    end

    defp build_contexts(args, outter_context, options) do
      {vars, outter_context} =
        Enum.reduce(args, {%{}, outter_context}, fn {k, v}, {args, outter_context} ->
          {:ok, value, outter_context} = Argument.get(v, outter_context, [], options)
          {Map.put(args, k, value), outter_context}
        end)

      inner_context = %Context{vars: vars}
      {[inner_context], outter_context}
    end

    defp build_forloop_map(index, length) do
      %{
        "index" => index + 1,
        "index0" => index,
        "rindex" => length - index,
        "rindex0" => length - index - 1,
        "first" => index == 0,
        "last" => length == index + 1,
        "length" => length
      }
    end

    defp cache_key(template) do
      :md5
      |> :crypto.hash(template)
      |> Base.encode16(case: :lower)
    end

    defp parse_and_cache_partial(template_str, options, cache_key, cache_module) do
      with {:ok, template} <- Solid.parse(template_str, options) do
        cache_module.put(cache_key, template)
        {:ok, template}
      end
    end
  end
end
