defmodule TinyLlmTalk.GrammarRules do
  @moduledoc """
  The grammar's rules, read out of `TinyLlm.Grammar`'s own documentation.

  The rules are written once, in the model repo, as an indented block in that
  module's moduledoc. The slide that shows them quotes that block rather than
  a copy, so the deck cannot claim a grammar the corpus was not written by.
  The sampling percentages are dropped: on a slide they are noise, and the
  speaker says what matters about them.
  """

  @rule ~r/^\s*(\w+)\s+->\s+(.*)$/
  @alternative ~r/^\s*\|\s+(.*)$/
  @percentage ~r/\s*\(\d+%\)\s*$/

  @doc "Each nonterminal with its alternatives, in the order the moduledoc lists them."
  @spec rules() :: [{String.t(), [String.t()]}]
  def rules do
    TinyLlm.Grammar
    |> moduledoc()
    |> String.split("\n")
    |> Enum.reduce([], &collect/2)
    |> Enum.reverse()
    |> Enum.map(fn {name, alternatives} -> {name, Enum.reverse(alternatives)} end)
  end

  ## PRIVATE FUNCTIONS

  defp moduledoc(module) do
    {:docs_v1, _annotation, :elixir, _format, %{"en" => doc}, _metadata, _docs} =
      Code.fetch_docs(module)

    doc
  end

  defp collect(line, rules) do
    cond do
      match = Regex.run(@rule, line) ->
        [_line, name, alternative] = match
        [{name, [strip(alternative)]} | rules]

      match = Regex.run(@alternative, line) ->
        [_line, alternative] = match
        [{name, alternatives} | rest] = rules
        [{name, [strip(alternative) | alternatives]} | rest]

      true ->
        rules
    end
  end

  defp strip(alternative), do: String.replace(alternative, @percentage, "")
end
