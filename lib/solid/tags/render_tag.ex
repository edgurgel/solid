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
    @default_max_render_depth 100
    @default_max_render_count 100_000

    def render(tag, context, options) do
      cache_module = Keyword.get(options, :cache_module, Solid.Caching.NoCache)

      {file_system, instance} = options[:file_system] || {Solid.BlankFileSystem, nil}

      options = Keyword.put(options, :tags, context.tags)

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
              {text, context} = render_partial(template, tag, inner_context, context, options)
              {[text | result], context}
            end)

          {Enum.reverse(rendered_text), context}

        {:error, exception} ->
          {[], Solid.Context.put_errors(context, [exception])}
      end
    end

    # The depth limit alone does not bound the work a partial can trigger: a partial rendering
    # itself twice fans out into 2^max_render_depth renders. The count limit bounds the whole
    # render tree, the depth limit keeps a single branch from recursing forever.
    #
    # Renders blocked by a limit are counted too. A partial rendering many partials produces one
    # blocked render per partial it lists, and only the budget keeps that from going on forever
    defp render_partial(template, tag, inner_context, context, options) do
      max_depth = limit(options, :max_render_depth, @default_max_render_depth)
      max_count = limit(options, :max_render_count, @default_max_render_count)
      depth = context.render_depth + 1
      count = context.render_count + 1
      context = %{context | render_count: count}

      cond do
        exceeded?(depth, max_depth) ->
          error = %Solid.RenderDepthError{
            max_depth: max_depth,
            template: tag.template,
            loc: tag.loc
          }

          {[], Solid.Context.put_errors(context, error)}

        exceeded?(count, max_count) ->
          # Only the render that runs out of budget reports it: the ones after it would all
          # repeat the same thing about a render tree that is already being cut short
          if count == max_count + 1 do
            error = %Solid.RenderCountError{
              max_count: max_count,
              template: tag.template,
              loc: tag.loc
            }

            {[], Solid.Context.put_errors(context, error)}
          else
            {[], context}
          end

        true ->
          inner_context = %{inner_context | render_depth: depth, render_count: count}

          {rendered_text, inner_context} =
            Solid.render_template(template, inner_context, options)

          context = %{context | render_count: inner_context.render_count}

          {rendered_text, Solid.Context.put_errors(context, inner_context.errors)}
      end
    end

    defp exceeded?(_value, :infinity), do: false
    defp exceeded?(value, limit), do: value > limit

    defp limit(options, key, default) do
      case Keyword.fetch(options, key) do
        :error -> default
        {:ok, :infinity} -> :infinity
        {:ok, limit} when is_integer(limit) and limit > 0 -> limit
        {:ok, invalid} -> raise ArgumentError, invalid_limit_message(key, invalid)
      end
    end

    defp invalid_limit_message(key, invalid) do
      "expected #{inspect(key)} to be a positive integer or :infinity, got: #{inspect(invalid)}"
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
