defmodule TinyLlmTalk.Source do
  @moduledoc """
  Reads the model's source out of the sibling `tiny_llm` checkout, at request
  time, by function name.

  Code slides quote the repo by reference instead of by copy and paste, so a
  slide cannot drift from the code it claims to show. Rename a function in
  `tiny_llm` and the slide raises during rehearsal, which is the moment you
  want to hear about it.
  """

  @type quotation :: %{
          path: String.t(),
          first_line: pos_integer(),
          last_line: pos_integer(),
          code: String.t(),
          location: String.t()
        }

  @spec root() :: String.t()
  def root, do: Application.fetch_env!(:tiny_llm_talk, :source_root)

  @spec read(String.t()) :: String.t()
  def read(relative_path) do
    root() |> Path.join(relative_path) |> File.read!()
  end

  @doc """
  The first clause of the named function, dedented to the left margin.

      iex> TinyLlmTalk.Source.function("lib/tiny_llm/attention.ex", :attend).first_line
      195
  """
  @spec function(String.t(), atom()) :: quotation()
  def function(relative_path, name) do
    lines = relative_path |> read() |> String.split("\n")
    pattern = definition_pattern(name)

    case Enum.find_index(lines, &Regex.match?(pattern, &1)) do
      nil ->
        raise ArgumentError, "no definition of #{name} in #{Path.join(root(), relative_path)}"

      offset ->
        body = lines |> Enum.drop(offset) |> take_definition()
        quotation(relative_path, offset + 1, body)
    end
  end

  @doc "An explicit line range, for the times a function is not the unit you want."
  @spec lines(String.t(), Range.t()) :: quotation()
  def lines(relative_path, first..last//1) do
    body =
      relative_path
      |> read()
      |> String.split("\n")
      |> Enum.slice((first - 1)..(last - 1)//1)

    quotation(relative_path, first, body)
  end

  ## PRIVATE FUNCTIONS

  defp quotation(relative_path, first_line, body) do
    last_line = first_line + length(body) - 1

    %{
      path: relative_path,
      first_line: first_line,
      last_line: last_line,
      code: body |> dedent() |> Enum.join("\n"),
      location: location(relative_path, first_line, last_line)
    }
  end

  # Slide line numbers count from one so the room can count them, so the caption
  # carries the real range in the file instead.
  defp location(relative_path, line, line), do: "#{relative_path}:#{line}"
  defp location(relative_path, first, last), do: "#{relative_path}:#{first}-#{last}"

  defp definition_pattern(name) do
    ~r/^\s*defp?\s+#{Regex.escape(to_string(name))}(\(|\s|,|$)/
  end

  # A one-line `def foo, do: bar` has no `end` to look for. Everything else
  # closes on an `end` at the same indentation as the `def`.
  defp take_definition([head | rest] = lines) do
    if String.contains?(head, ", do:") do
      [head]
    else
      closing = indentation(head) <> "end"
      Enum.take(lines, 2 + (Enum.find_index(rest, &(&1 == closing)) || 0))
    end
  end

  defp indentation(line), do: String.replace(line, ~r/\S.*/, "")

  defp dedent(lines) do
    margin =
      lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(&String.length(indentation(&1)))
      |> Enum.min(fn -> 0 end)

    Enum.map(lines, fn
      "" -> ""
      line -> String.slice(line, margin..-1//1)
    end)
  end
end
